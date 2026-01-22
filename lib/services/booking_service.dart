import 'package:cloud_firestore/cloud_firestore.dart';

/// 冲突检测结果
class ConflictCheckResult {
  final bool hasConflict;
  final int currentBookings; // 当前时段已有预订数
  final int maxSlots; // 最大可用槽位
  final List<Map<String, dynamic>> conflictingBookings;

  ConflictCheckResult({
    required this.hasConflict,
    this.currentBookings = 0,
    this.maxSlots = 1,
    this.conflictingBookings = const [],
  });

  /// 剩余可用槽位
  int get availableSlots => maxSlots - currentBookings;
}

class BookingService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('bookings');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 获取设施的最大槽位数
  Future<int> _getFacilityMaxSlots(String facilityId) async {
    final doc = await _firestore.collection('facilities').doc(facilityId).get();
    if (!doc.exists) return 1;
    final data = doc.data();
    return data?['maxSlots'] as int? ?? 1;
  }

  /// 检查时间段是否有冲突
  /// 冲突条件: 同一设施 + 同一天 + 时间段重叠 + 已预订数 >= maxSlots
  Future<ConflictCheckResult> checkConflict({
    required String facilityId,
    required DateTime bookingDate,
    required int durationHours,
    String? excludeBookingId, // 改期时排除自己
    int? maxSlots, // 可选传入，避免重复查询
  }) async {
    // 获取设施最大槽位
    final slots = maxSlots ?? await _getFacilityMaxSlots(facilityId);

    // 计算预订的开始和结束时间
    final startTime = bookingDate;
    final endTime = bookingDate.add(Duration(hours: durationHours));

    // 获取同一天的开始和结束
    final dayStart = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 查询同一设施、同一天的预订
    final snap = await _col
        .where('facilityId', isEqualTo: facilityId)
        .where('bookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('bookingDate', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    final overlappingBookings = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      // 排除自己（改期场景）
      if (excludeBookingId != null && doc.id == excludeBookingId) continue;

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';

      // 只检查 approved 状态（预订自动通过，无需审批）
      if (status != 'approved') continue;

      // 获取已有预订的时间
      final existingStart = (data['bookingDate'] as Timestamp).toDate();
      final existingDuration = data['durationHours'] as int;
      final existingEnd = existingStart.add(Duration(hours: existingDuration));

      // 检查时间段是否重叠
      // 重叠条件: 新开始 < 已有结束 && 新结束 > 已有开始
      if (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart)) {
        overlappingBookings.add({
          'id': doc.id,
          'startTime': existingStart,
          'endTime': existingEnd,
          ...data,
        });
      }
    }

    // 如果重叠预订数 >= maxSlots，则有冲突
    final hasConflict = overlappingBookings.length >= slots;

    return ConflictCheckResult(
      hasConflict: hasConflict,
      currentBookings: overlappingBookings.length,
      maxSlots: slots,
      conflictingBookings: hasConflict ? overlappingBookings : [],
    );
  }

  /// 创建预订（带冲突检测和时间验证）
  Future<void> createBooking({
    required String residentId,
    required String facilityId,
    required DateTime bookingDate,
    required int durationHours,
  }) async {
    // 验证 1: 预订时间不能是过去
    if (bookingDate.isBefore(DateTime.now())) {
      throw BookingValidationException('Cannot book a time slot in the past');
    }

    // 验证 2: Duration 必须是 1 或 2 小时
    if (durationHours < 1 || durationHours > 2) {
      throw BookingValidationException('Duration must be 1 or 2 hours');
    }

    // 检查冲突
    final conflict = await checkConflict(
      facilityId: facilityId,
      bookingDate: bookingDate,
      durationHours: durationHours,
    );

    if (conflict.hasConflict) {
      throw BookingConflictException(
        'This time slot is already booked',
        conflict.conflictingBookings,
      );
    }

    await _col.add({
      'residentId': residentId,
      'facilityId': facilityId,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'durationHours': durationHours,
      'status': 'approved', // 自动通过，无需审批
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamMyBookings(String residentId) {
    return _col
        .where('residentId', isEqualTo: residentId)
        .orderBy('bookingDate', descending: true)
        .snapshots();
  }

  /// 获取所有已确认的预订（供 Security 查看）
  Stream<QuerySnapshot> streamAllBookings({DateTime? fromDate}) {
    var query = _col.where('status', isEqualTo: 'approved');
    
    if (fromDate != null) {
      query = query.where('bookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }
    
    return query.orderBy('bookingDate', descending: true).snapshots();
  }

  /// 获取今日预订
  Stream<QuerySnapshot> streamTodayBookings() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    
    return _col
        .where('status', isEqualTo: 'approved')
        .where('bookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('bookingDate', isLessThan: Timestamp.fromDate(tomorrowStart))
        .orderBy('bookingDate')
        .snapshots();
  }

  /// 取消预订
  Future<void> cancelBooking(String bookingId) {
    return _col.doc(bookingId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// 改期预订（带冲突检测和时间验证）
  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime newBookingDate,
    required int newDurationHours,
  }) async {
    // 验证 1: 预订时间不能是过去
    if (newBookingDate.isBefore(DateTime.now())) {
      throw BookingValidationException('Cannot reschedule to a time in the past');
    }

    // 验证 2: Duration 必须是 1 或 2 小时
    if (newDurationHours < 1 || newDurationHours > 2) {
      throw BookingValidationException('Duration must be 1 or 2 hours');
    }

    // 获取原预订信息
    final doc = await _col.doc(bookingId).get();
    if (!doc.exists) throw Exception('Booking not found');

    final data = doc.data() as Map<String, dynamic>;
    final facilityId = data['facilityId'] as String;

    // 检查新时间段是否有冲突（排除自己）
    final conflict = await checkConflict(
      facilityId: facilityId,
      bookingDate: newBookingDate,
      durationHours: newDurationHours,
      excludeBookingId: bookingId,
    );

    if (conflict.hasConflict) {
      throw BookingConflictException(
        'The new time slot is already booked',
        conflict.conflictingBookings,
      );
    }

    // 更新预订
    await _col.doc(bookingId).update({
      'bookingDate': Timestamp.fromDate(newBookingDate),
      'durationHours': newDurationHours,
      'rescheduledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBookingStatus(String bookingId, String status) {
    return _col.doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 检查预订是否可以取消
  bool canCancel(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';
    final bookingDate = (booking['bookingDate'] as Timestamp).toDate();

    // 已取消的不能再取消
    if (status == 'cancelled') return false;

    // 已过去的预订不能取消
    if (bookingDate.isBefore(DateTime.now())) return false;

    return true;
  }

  /// 检查预订是否可以改期
  bool canReschedule(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';
    final bookingDate = (booking['bookingDate'] as Timestamp).toDate();

    // 已取消的不能改期
    if (status == 'cancelled') return false;

    // 已过去的预订不能改期
    if (bookingDate.isBefore(DateTime.now())) return false;

    return true;
  }
}

/// 预订冲突异常
class BookingConflictException implements Exception {
  final String message;
  final List<Map<String, dynamic>> conflictingBookings;

  BookingConflictException(this.message, this.conflictingBookings);

  @override
  String toString() => message;
}

/// 预订验证异常（时间、时长等）
class BookingValidationException implements Exception {
  final String message;

  BookingValidationException(this.message);

  @override
  String toString() => message;
}