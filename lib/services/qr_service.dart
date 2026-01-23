// lib/services/qr_service.dart
// QR 码生成和验证服务

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// QR 码服务 - 处理访客 QR 码的生成和验证
class QrService {
  static final QrService _instance = QrService._internal();
  factory QrService() => _instance;
  QrService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 密钥（实际项目应存储在安全位置，如 Firebase Remote Config）
  static const String _secretKey = 'vanguard_qr_secret_2024';

  /// 生成 QR 码数据
  /// 返回加密的 QR 码字符串
  String generateQrCode({
    required String visitorId,
    required DateTime expiresAt,
  }) {
    final payload = {
      'vid': visitorId,
      'exp': expiresAt.millisecondsSinceEpoch,
    };
    
    // 生成签名
    final dataString = '${payload['vid']}_${payload['exp']}_$_secretKey';
    final signature = sha256.convert(utf8.encode(dataString)).toString().substring(0, 16);
    payload['sig'] = signature;
    
    // 转换为 Base64
    final jsonString = jsonEncode(payload);
    final qrCode = base64Encode(utf8.encode(jsonString));
    
    debugPrint('🔐 QR Code generated for visitor: $visitorId');
    return qrCode;
  }

  /// 验证 QR 码
  /// 返回验证结果
  Future<QrVerificationResult> verifyQrCode(String qrCode) async {
    try {
      // 解码 Base64
      final jsonString = utf8.decode(base64Decode(qrCode));
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final visitorId = payload['vid'] as String?;
      final expTimestamp = payload['exp'] as int?;
      final signature = payload['sig'] as String?;
      
      if (visitorId == null || expTimestamp == null || signature == null) {
        return QrVerificationResult.invalid('Invalid QR code format');
      }
      
      // 验证签名
      final expectedDataString = '${visitorId}_${expTimestamp}_$_secretKey';
      final expectedSignature = sha256.convert(utf8.encode(expectedDataString)).toString().substring(0, 16);
      
      if (signature != expectedSignature) {
        return QrVerificationResult.invalid('Invalid signature - QR code may be forged');
      }
      
      // 检查是否过期
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expTimestamp);
      if (DateTime.now().isAfter(expiresAt)) {
        return QrVerificationResult.expired('QR code has expired');
      }
      
      // 从 Firestore 获取访客信息
      final visitorDoc = await _firestore.collection('visitors').doc(visitorId).get();
      
      if (!visitorDoc.exists) {
        return QrVerificationResult.invalid('Visitor not found');
      }
      
      final visitorData = visitorDoc.data()!;
      final status = visitorData['status'] as String? ?? '';
      
      // 检查状态
      if (status == 'expired') {
        return QrVerificationResult.expired('This visitor pass has expired');
      }
      if (status == 'denied') {
        return QrVerificationResult.invalid('This visitor was denied entry');
      }
      if (status == 'checked-out') {
        return QrVerificationResult.invalid('Visitor has already checked out');
      }
      
      return QrVerificationResult.valid(
        visitorId: visitorId,
        visitorData: visitorData,
        currentStatus: status,
      );
      
    } catch (e) {
      debugPrint('❌ QR verification error: $e');
      return QrVerificationResult.invalid('Failed to read QR code');
    }
  }

  /// 计算 Walk-in 访客的 QR 过期时间（24 小时后）
  DateTime calculateWalkInExpiry() {
    return DateTime.now().add(const Duration(hours: 24));
  }

  /// 计算 By-car 访客的 QR 过期时间
  /// 基于当前时间计算，最晚到次日凌晨 2 点
  DateTime calculateCarQrExpiry() {
    final now = DateTime.now();
    
    // 计算今天或明天的凌晨 2 点
    DateTime deadline;
    if (now.hour < 2) {
      // 如果现在还没到 2 点，截止到今天 2 点
      deadline = DateTime(now.year, now.month, now.day, 2, 0);
    } else {
      // 如果已过 2 点，截止到明天 2 点
      deadline = DateTime(now.year, now.month, now.day + 1, 2, 0);
    }
    
    return deadline;
  }

  /// 计算停车截止时间（Check-in 时调用）
  /// 返回：min(现在 + 4小时, 凌晨2点)
  DateTime calculateParkingDeadline() {
    final now = DateTime.now();
    final fourHoursLater = now.add(const Duration(hours: 4));
    
    // 计算今天或明天的凌晨 2 点
    DateTime twoAm;
    if (now.hour < 2) {
      twoAm = DateTime(now.year, now.month, now.day, 2, 0);
    } else {
      twoAm = DateTime(now.year, now.month, now.day + 1, 2, 0);
    }
    
    // 取较早的时间
    return fourHoursLater.isBefore(twoAm) ? fourHoursLater : twoAm;
  }

  /// 审批访客并生成 QR 码
  Future<String> approveVisitorAndGenerateQr({
    required String visitorId,
    required String entryType,
  }) async {
    final DateTime expiresAt;
    
    if (entryType == 'walk-in') {
      expiresAt = calculateWalkInExpiry();
    } else {
      expiresAt = calculateCarQrExpiry();
    }
    
    final qrCode = generateQrCode(
      visitorId: visitorId,
      expiresAt: expiresAt,
    );
    
    // 更新 Firestore
    await _firestore.collection('visitors').doc(visitorId).update({
      'status': 'approved',
      'qrCode': qrCode,
      'qrExpiresAt': Timestamp.fromDate(expiresAt),
      'approvedAt': FieldValue.serverTimestamp(),
    });
    
    debugPrint('✅ Visitor approved: $visitorId, QR expires at: $expiresAt');
    return qrCode;
  }

  /// Check-in 访客
  Future<void> checkInVisitor(String visitorId, String entryType) async {
    final updateData = <String, dynamic>{
      'status': 'checked-in',
      'checkedInAt': FieldValue.serverTimestamp(),
    };
    
    // 如果是 car，计算停车截止时间
    if (entryType == 'car') {
      final deadline = calculateParkingDeadline();
      updateData['parkingDeadline'] = Timestamp.fromDate(deadline);
      debugPrint('🚗 Parking deadline set: $deadline');
    }
    
    await _firestore.collection('visitors').doc(visitorId).update(updateData);
    debugPrint('✅ Visitor checked in: $visitorId');
  }

  /// Check-out 访客
  Future<void> checkOutVisitor(String visitorId) async {
    await _firestore.collection('visitors').doc(visitorId).update({
      'status': 'checked-out',
      'checkedOutAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Visitor checked out: $visitorId');
  }
}

/// QR 码验证结果
class QrVerificationResult {
  final bool isValid;
  final bool isExpired;
  final String? errorMessage;
  final String? visitorId;
  final Map<String, dynamic>? visitorData;
  final String? currentStatus;

  QrVerificationResult._({
    required this.isValid,
    this.isExpired = false,
    this.errorMessage,
    this.visitorId,
    this.visitorData,
    this.currentStatus,
  });

  factory QrVerificationResult.valid({
    required String visitorId,
    required Map<String, dynamic> visitorData,
    required String currentStatus,
  }) {
    return QrVerificationResult._(
      isValid: true,
      visitorId: visitorId,
      visitorData: visitorData,
      currentStatus: currentStatus,
    );
  }

  factory QrVerificationResult.invalid(String message) {
    return QrVerificationResult._(
      isValid: false,
      errorMessage: message,
    );
  }

  factory QrVerificationResult.expired(String message) {
    return QrVerificationResult._(
      isValid: false,
      isExpired: true,
      errorMessage: message,
    );
  }
}
