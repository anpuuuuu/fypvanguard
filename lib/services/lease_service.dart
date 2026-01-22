// lib/services/lease_service.dart
// 租约管理服务 - 处理租户租约生命周期

import 'package:cloud_firestore/cloud_firestore.dart';

/// 租约状态枚举
enum LeaseStatus {
  active,       // 正常（剩余 > 30 天）
  expiringSoon, // 即将到期（剩余 1-30 天）
  expired,      // 已过期
  noLease,      // 无租约信息
}

/// 租约信息模型
class LeaseInfo {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? leaseMonths;
  final double? monthlyRent;
  final String? notes;
  final LeaseStatus status;
  final int daysLeft;

  LeaseInfo({
    this.startDate,
    this.endDate,
    this.leaseMonths,
    this.monthlyRent,
    this.notes,
    required this.status,
    required this.daysLeft,
  });

  /// 从 Firestore 数据创建 LeaseInfo
  factory LeaseInfo.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return LeaseInfo(status: LeaseStatus.noLease, daysLeft: 0);
    }

    DateTime? startDate;
    DateTime? endDate;

    // 解析开始日期
    final startRaw = data['leaseStartDate'];
    if (startRaw is Timestamp) {
      startDate = startRaw.toDate();
    }

    // 解析结束日期
    final endRaw = data['leaseEndDate'];
    if (endRaw is Timestamp) {
      endDate = endRaw.toDate();
    }

    // 计算剩余天数和状态
    final now = DateTime.now();
    int daysLeft = 0;
    LeaseStatus status = LeaseStatus.noLease;

    if (endDate != null) {
      daysLeft = endDate.difference(now).inDays;
      
      if (daysLeft < 0) {
        status = LeaseStatus.expired;
      } else if (daysLeft <= 30) {
        status = LeaseStatus.expiringSoon;
      } else {
        status = LeaseStatus.active;
      }
    }

    return LeaseInfo(
      startDate: startDate,
      endDate: endDate,
      leaseMonths: data['leaseMonths'] as int?,
      monthlyRent: (data['monthlyRent'] as num?)?.toDouble(),
      notes: data['leaseNotes'] as String?,
      status: status,
      daysLeft: daysLeft,
    );
  }

  /// 获取状态显示文字
  String get statusText {
    switch (status) {
      case LeaseStatus.active:
        return 'Active';
      case LeaseStatus.expiringSoon:
        return 'Expiring Soon';
      case LeaseStatus.expired:
        return 'Expired';
      case LeaseStatus.noLease:
        return 'No Lease';
    }
  }

  /// 获取剩余天数显示文字
  String get daysLeftText {
    if (status == LeaseStatus.noLease) return '-';
    if (status == LeaseStatus.expired) {
      return 'Expired ${-daysLeft} days ago';
    }
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }

  /// 计算租约进度百分比 (0.0 - 1.0)
  double get progress {
    if (startDate == null || endDate == null) return 0.0;
    
    final now = DateTime.now();
    final totalDays = endDate!.difference(startDate!).inDays;
    final elapsedDays = now.difference(startDate!).inDays;
    
    if (totalDays <= 0) return 1.0;
    
    final progress = elapsedDays / totalDays;
    return progress.clamp(0.0, 1.0);
  }
}

/// 租约服务类
class LeaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 获取租户的租约信息
  Future<LeaseInfo> getLeaseInfo(String tenantId) async {
    final doc = await _firestore.collection('residents').doc(tenantId).get();
    return LeaseInfo.fromMap(doc.data());
  }

  /// 检查并更新租户的租约状态
  /// 返回更新后的状态
  Future<LeaseStatus> checkAndUpdateLeaseStatus(String tenantId) async {
    final residentDoc = await _firestore.collection('residents').doc(tenantId).get();
    final leaseInfo = LeaseInfo.fromMap(residentDoc.data());

    // 更新 accounts 表中的状态
    String accountStatus;
    switch (leaseInfo.status) {
      case LeaseStatus.active:
        accountStatus = 'active';
        break;
      case LeaseStatus.expiringSoon:
        accountStatus = 'expiring_soon';
        break;
      case LeaseStatus.expired:
        accountStatus = 'expired';
        break;
      case LeaseStatus.noLease:
        accountStatus = 'active'; // 无租约信息时保持 active
        break;
    }

    await _firestore.collection('accounts').doc(tenantId).update({
      'status': accountStatus,
      'leaseCheckedAt': FieldValue.serverTimestamp(),
    });

    return leaseInfo.status;
  }

  /// 批量检查业主下所有租户的租约状态
  Future<Map<String, LeaseStatus>> checkAllTenantsForOwner(String ownerId) async {
    // 获取业主的 unit
    final ownerDoc = await _firestore.collection('residents').doc(ownerId).get();
    final unitNumber = ownerDoc.data()?['unitNumber'] as String?;
    
    if (unitNumber == null || unitNumber.isEmpty) {
      return {};
    }

    // 获取该 unit 下的所有租户
    final tenantsSnap = await _firestore
        .collection('residents')
        .where('unitNumber', isEqualTo: unitNumber)
        .get();

    final results = <String, LeaseStatus>{};

    for (final doc in tenantsSnap.docs) {
      // 检查是否是租户
      final accountSnap = await _firestore.collection('accounts').doc(doc.id).get();
      final role = accountSnap.data()?['role'] as String?;
      
      if (role == 'tenant') {
        final status = await checkAndUpdateLeaseStatus(doc.id);
        results[doc.id] = status;
      }
    }

    return results;
  }

  /// 设置租约信息
  Future<void> setLeaseInfo({
    required String tenantId,
    required DateTime startDate,
    required DateTime endDate,
    required int leaseMonths,
    double? monthlyRent,
    String? notes,
  }) async {
    await _firestore.collection('residents').doc(tenantId).update({
      'leaseStartDate': Timestamp.fromDate(startDate),
      'leaseEndDate': Timestamp.fromDate(endDate),
      'leaseMonths': leaseMonths,
      if (monthlyRent != null) 'monthlyRent': monthlyRent,
      if (notes != null) 'leaseNotes': notes,
    });

    // 同时更新账户状态
    await checkAndUpdateLeaseStatus(tenantId);
  }

  /// 延长租约
  Future<void> extendLease({
    required String tenantId,
    required int additionalMonths,
    double? newMonthlyRent,
  }) async {
    final residentDoc = await _firestore.collection('residents').doc(tenantId).get();
    final data = residentDoc.data();
    
    if (data == null) return;

    // 获取当前结束日期
    DateTime currentEndDate;
    final endRaw = data['leaseEndDate'];
    if (endRaw is Timestamp) {
      currentEndDate = endRaw.toDate();
    } else {
      currentEndDate = DateTime.now();
    }

    // 如果已过期，从今天开始计算
    final now = DateTime.now();
    final baseDate = currentEndDate.isBefore(now) ? now : currentEndDate;
    
    // 计算新的结束日期
    final newEndDate = DateTime(
      baseDate.year,
      baseDate.month + additionalMonths,
      baseDate.day,
    );

    // 更新旧的月数
    final oldMonths = data['leaseMonths'] as int? ?? 0;

    await _firestore.collection('residents').doc(tenantId).update({
      'leaseEndDate': Timestamp.fromDate(newEndDate),
      'leaseMonths': oldMonths + additionalMonths,
      if (newMonthlyRent != null) 'monthlyRent': newMonthlyRent,
      'leaseExtendedAt': FieldValue.serverTimestamp(),
    });

    // 重新激活账户
    await _firestore.collection('accounts').doc(tenantId).update({
      'status': 'active',
    });
  }

  /// 获取业主信息（用于过期页面显示）
  Future<Map<String, String>> getOwnerInfo(String ownerId) async {
    final doc = await _firestore.collection('residents').doc(ownerId).get();
    final data = doc.data() ?? {};
    return {
      'fullName': data['fullName'] as String? ?? 'Unknown',
      'contactNumber': data['contactNumber'] as String? ?? '-',
    };
  }

  /// 统计即将到期和已过期的租户数量
  Future<Map<String, int>> getExpiryStats(String ownerId) async {
    final ownerDoc = await _firestore.collection('residents').doc(ownerId).get();
    final unitNumber = ownerDoc.data()?['unitNumber'] as String?;
    
    if (unitNumber == null) return {'expiringSoon': 0, 'expired': 0};

    final tenantsSnap = await _firestore
        .collection('residents')
        .where('unitNumber', isEqualTo: unitNumber)
        .get();

    int expiringSoon = 0;
    int expired = 0;

    for (final doc in tenantsSnap.docs) {
      final accountSnap = await _firestore.collection('accounts').doc(doc.id).get();
      final role = accountSnap.data()?['role'] as String?;
      
      if (role == 'tenant') {
        final leaseInfo = LeaseInfo.fromMap(doc.data());
        if (leaseInfo.status == LeaseStatus.expiringSoon) {
          expiringSoon++;
        } else if (leaseInfo.status == LeaseStatus.expired) {
          expired++;
        }
      }
    }

    return {'expiringSoon': expiringSoon, 'expired': expired};
  }
}
