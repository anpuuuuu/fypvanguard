// lib/services/qr_service.dart
// Visitor QR code generation and verification.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for creating and validating signed visitor QR payloads.
class QrService {
  static final QrService _instance = QrService._internal();
  factory QrService() => _instance;
  QrService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Shared secret for HMAC-style signing (production: use Remote Config / server).
  static const String _secretKey = 'vanguard_qr_secret_2024';

  /// Builds a signed, Base64-encoded QR payload for [visitorId] valid until [expiresAt].
  String generateQrCode({
    required String visitorId,
    required DateTime expiresAt,
  }) {
    final payload = {
      'vid': visitorId,
      'exp': expiresAt.millisecondsSinceEpoch,
    };

    // Sign payload so tampering is detectable
    final dataString = '${payload['vid']}_${payload['exp']}_$_secretKey';
    final signature = sha256.convert(utf8.encode(dataString)).toString().substring(0, 16);
    payload['sig'] = signature;

    // Encode as Base64 for QR content
    final jsonString = jsonEncode(payload);
    final qrCode = base64Encode(utf8.encode(jsonString));

    debugPrint('🔐 QR Code generated for visitor: $visitorId');
    return qrCode;
  }

  /// Decodes and verifies a scanned QR string; loads visitor from Firestore when valid.
  Future<QrVerificationResult> verifyQrCode(String qrCode) async {
    try {
      // Decode Base64 JSON payload
      final jsonString = utf8.decode(base64Decode(qrCode));
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;

      final visitorId = payload['vid'] as String?;
      final expTimestamp = payload['exp'] as int?;
      final signature = payload['sig'] as String?;

      if (visitorId == null || expTimestamp == null || signature == null) {
        return QrVerificationResult.invalid('Invalid QR code format');
      }

      // Recompute signature
      final expectedDataString = '${visitorId}_${expTimestamp}_$_secretKey';
      final expectedSignature = sha256.convert(utf8.encode(expectedDataString)).toString().substring(0, 16);

      if (signature != expectedSignature) {
        return QrVerificationResult.invalid('Invalid signature - QR code may be forged');
      }

      // Expiry from payload timestamp
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expTimestamp);
      if (DateTime.now().isAfter(expiresAt)) {
        return QrVerificationResult.expired('QR code has expired');
      }

      // Load visitor record
      final visitorDoc = await _firestore.collection('visitors').doc(visitorId).get();

      if (!visitorDoc.exists) {
        return QrVerificationResult.invalid('Visitor not found');
      }

      final visitorData = visitorDoc.data()!;
      final status = visitorData['status'] as String? ?? '';

      // Business rules by status
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

  /// Walk-in pass expiry: 24 hours from now.
  DateTime calculateWalkInExpiry() {
    return DateTime.now().add(const Duration(hours: 24));
  }

  /// By-car pass expiry: 2:00 AM same day if before 2 AM, else 2:00 AM next day.
  DateTime calculateCarQrExpiry() {
    final now = DateTime.now();

    DateTime deadline;
    if (now.hour < 2) {
      deadline = DateTime(now.year, now.month, now.day, 2, 0);
    } else {
      deadline = DateTime(now.year, now.month, now.day + 1, 2, 0);
    }

    return deadline;
  }

  /// Parking deadline after check-in: min(now + 4h, next 2 AM boundary).
  DateTime calculateParkingDeadline() {
    final now = DateTime.now();
    final fourHoursLater = now.add(const Duration(hours: 4));

    DateTime twoAm;
    if (now.hour < 2) {
      twoAm = DateTime(now.year, now.month, now.day, 2, 0);
    } else {
      twoAm = DateTime(now.year, now.month, now.day + 1, 2, 0);
    }

    return fourHoursLater.isBefore(twoAm) ? fourHoursLater : twoAm;
  }

  /// Approves visitor and persists generated QR + expiry to Firestore.
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

    await _firestore.collection('visitors').doc(visitorId).update({
      'status': 'approved',
      'qrCode': qrCode,
      'qrExpiresAt': Timestamp.fromDate(expiresAt),
      'approvedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Visitor approved: $visitorId, QR expires at: $expiresAt');
    return qrCode;
  }

  /// Marks visitor checked in; sets parking deadline for car entry.
  Future<void> checkInVisitor(String visitorId, String entryType) async {
    final updateData = <String, dynamic>{
      'status': 'checked-in',
      'checkedInAt': FieldValue.serverTimestamp(),
    };

    if (entryType == 'car') {
      final deadline = calculateParkingDeadline();
      updateData['parkingDeadline'] = Timestamp.fromDate(deadline);
      debugPrint('🚗 Parking deadline set: $deadline');
    }

    await _firestore.collection('visitors').doc(visitorId).update(updateData);
    debugPrint('✅ Visitor checked in: $visitorId');
  }

  /// Marks visitor checked out.
  Future<void> checkOutVisitor(String visitorId) async {
    await _firestore.collection('visitors').doc(visitorId).update({
      'status': 'checked-out',
      'checkedOutAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Visitor checked out: $visitorId');
  }
}

/// Outcome of QR verification (valid, invalid, or expired).
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
