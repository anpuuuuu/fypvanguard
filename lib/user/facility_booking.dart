// lib/user/facility_booking.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/booking_service.dart';
import 'RegisterVisitorForm.dart';

/// Model for a facility document, including hours and optional image.
class Facility {
  final String id;
  final String name;
  final int startHour;
  final int endHour;
  final int maxSlots; // 同一时段最大预订数
  final String? imageBase64;

  Facility({
    required this.id,
    required this.name,
    required this.startHour,
    required this.endHour,
    this.maxSlots = 1,
    this.imageBase64,
  });

  factory Facility.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Facility(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      startHour: data['startHour'] as int? ?? 0,
      endHour: data['endHour'] as int? ?? 24,
      maxSlots: data['maxSlots'] as int? ?? 1,
      imageBase64: data['imageBase64'] as String?,
    );
  }
}

class FacilityBookingPage extends StatefulWidget {
  const FacilityBookingPage({Key? key}) : super(key: key);

  @override
  _FacilityBookingPageState createState() => _FacilityBookingPageState();
}

class _FacilityBookingPageState extends State<FacilityBookingPage> {
  final _firestore = FirebaseFirestore.instance;
  final _bookingService = BookingService();

  bool _loadingFacilities = true;
  List<Facility> _facilities = [];
  Map<String, String> _facilityNames = {};
  Map<String, Facility> _facilityMap = {};

  Facility? _selectedFacility;
  DateTime? _selectedDate;
  int? _startHour;
  int? _durationHours;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final snap = await _firestore
          .collection('facilities')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      final facs = snap.docs.map((d) => Facility.fromDoc(d)).toList();
      setState(() {
        _facilities = facs;
        _facilityNames = {for (var f in facs) f.id: f.name};
        _facilityMap = {for (var f in facs) f.id: f};
        _loadingFacilities = false;
      });
    } catch (e) {
      setState(() => _loadingFacilities = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading facilities: $e',
              style: GoogleFonts.montserrat()),
          backgroundColor: Colors.red.shade300,
        ),
      );
    }
  }

  void _showEntryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Entry Type',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.directions_walk),
              label: Text('Walk-In', style: GoogleFonts.montserrat()),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const RegisterVisitorForm(entryType: 'walk-in')),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.directions_car),
              label: Text('By Car', style: GoogleFonts.montserrat()),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const RegisterVisitorForm(entryType: 'car')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _submitBooking() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    if (_selectedFacility == null ||
        _selectedDate == null ||
        _startHour == null ||
        _durationHours == null) {
      setState(() {
        _error = 'Please fill in all fields';
        _submitting = false;
      });
      return;
    }

    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startHour!,
    );

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await _bookingService.createBooking(
        residentId: user.uid,
        facilityId: _selectedFacility!.id,
        bookingDate: start,
        durationHours: _durationHours!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking confirmed!', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.green.shade400,
        ),
      );

      setState(() {
        _selectedFacility = null;
        _selectedDate = null;
        _startHour = null;
        _durationHours = null;
        _submitting = false;
      });
    } on BookingConflictException catch (e) {
      // 显示冲突提示
      setState(() {
        _error = null;
        _submitting = false;
      });
      _showConflictDialog(e.conflictingBookings, maxSlots: _selectedFacility?.maxSlots);
    } on BookingValidationException catch (e) {
      // 显示验证错误
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _submitting = false;
      });
    }
  }

  /// 显示冲突提示对话框
  void _showConflictDialog(List<Map<String, dynamic>> conflicts, {int? maxSlots}) {
    final slots = maxSlots ?? _selectedFacility?.maxSlots ?? 1;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.event_busy, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text('Slots Full',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All $slots slots are taken',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Text(
                          'for this time period',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Booked times:',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...conflicts.take(3).map((c) {
              final start = c['startTime'] as DateTime;
              final end = c['endTime'] as DateTime;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Text(
                      '${start.hour.toString().padLeft(2, '0')}:00 - ${end.hour.toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.montserrat(fontSize: 13),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (conflicts.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '... and ${conflicts.length - 3} more',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Please choose a different time.',
              style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('OK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// 显示取消确认对话框
  Future<void> _showCancelDialog(String bookingId, Map<String, dynamic> data) async {
    final facName = _facilityNames[data['facilityId'] as String] ?? 'Unknown';
    final ts = (data['bookingDate'] as Timestamp).toDate();
    final dur = data['durationHours'] as int;
    final end = ts.add(Duration(hours: dur));
    final dateStr = DateFormat('dd MMM yyyy').format(ts);
    final timeStr = '${ts.hour.toString().padLeft(2, '0')}:00 - ${end.hour.toString().padLeft(2, '0')}:00';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text('Cancel Booking?',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this booking?',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(facName,
                      style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('$dateStr  •  $timeStr',
                      style: GoogleFonts.montserrat(
                          fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('No, Keep It',
                style: GoogleFonts.montserrat(color: Colors.grey[700])),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Yes, Cancel', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _bookingService.cancelBooking(bookingId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled', style: GoogleFonts.montserrat()),
            backgroundColor: Colors.green.shade400,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.montserrat()),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  /// 显示改期对话框
  Future<void> _showRescheduleDialog(String bookingId, Map<String, dynamic> data) async {
    final facilityId = data['facilityId'] as String;
    final facility = _facilityMap[facilityId];
    if (facility == null) return;

    final currentTs = (data['bookingDate'] as Timestamp).toDate();
    final currentDur = data['durationHours'] as int;
    final currentEnd = currentTs.add(Duration(hours: currentDur));

    DateTime? newDate;
    int? newStartHour;
    int? newDuration;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final now = DateTime.now();
          final isToday = newDate != null &&
              newDate!.year == now.year &&
              newDate!.month == now.month &&
              newDate!.day == now.day;

          final hours = <int>[
            for (var h = facility.startHour; h < facility.endHour; h++)
              if (!(isToday && h <= now.hour)) h
          ];

          // Duration 限制为 1 或 2 小时
          final maxDur = (newStartHour != null)
              ? (facility.endHour - newStartHour!).clamp(0, 2)
              : 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.edit_calendar, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text('Reschedule Booking',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前预订信息
                  Text('Current Booking:',
                      style: GoogleFonts.montserrat(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd MMM yyyy').format(currentTs)}  •  ${currentTs.hour.toString().padLeft(2, '0')}:00 - ${currentEnd.hour.toString().padLeft(2, '0')}:00',
                            style: GoogleFonts.montserrat(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  Text('New Schedule:',
                      style: GoogleFonts.montserrat(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 12),

                  // 日期选择
                  InkWell(
                    onTap: () async {
                      final today = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: newDate ?? today,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          newDate = date;
                          newStartHour = null;
                          newDuration = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              newDate == null
                                  ? 'Pick a date'
                                  : DateFormat('dd MMM yyyy').format(newDate!),
                              style: GoogleFonts.montserrat(
                                color: newDate == null ? Colors.grey : Colors.black87,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 开始时间
                  if (newDate != null && hours.isNotEmpty)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      value: newStartHour,
                      items: hours
                          .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text('$h:00',
                                    style: GoogleFonts.montserrat()),
                              ))
                          .toList(),
                      onChanged: (h) {
                        setDialogState(() {
                          newStartHour = h;
                          newDuration = null;
                        });
                      },
                    ),

                  const SizedBox(height: 12),

                  // 时长
                  if (newStartHour != null && maxDur > 0)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      value: newDuration,
                      items: List.generate(maxDur, (i) => i + 1)
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d hour${d > 1 ? 's' : ''}',
                                    style: GoogleFonts.montserrat()),
                              ))
                          .toList(),
                      onChanged: (d) {
                        setDialogState(() => newDuration = d);
                      },
                    ),

                  const SizedBox(height: 16),

                  // 新时间预览
                  if (newDate != null && newStartHour != null && newDuration != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_available,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('New Time:',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 11, color: Colors.blue.shade700)),
                                Text(
                                  '${DateFormat('dd MMM yyyy').format(newDate!)}  •  ${newStartHour.toString().padLeft(2, '0')}:00 - ${(newStartHour! + newDuration!).toString().padLeft(2, '0')}:00',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),
                  Text(
                    'Conflict check will run automatically.',
                    style: GoogleFonts.montserrat(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel', style: GoogleFonts.montserrat()),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (newDate != null &&
                        newStartHour != null &&
                        newDuration != null)
                    ? () {
                        Navigator.pop(context, {
                          'date': newDate,
                          'hour': newStartHour,
                          'duration': newDuration,
                        });
                      }
                    : null,
                child: Text('Reschedule',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final newBookingDate = DateTime(
        result['date'].year,
        result['date'].month,
        result['date'].day,
        result['hour'],
      );

      try {
        await _bookingService.rescheduleBooking(
          bookingId: bookingId,
          newBookingDate: newBookingDate,
          newDurationHours: result['duration'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking rescheduled', style: GoogleFonts.montserrat()),
            backgroundColor: Colors.green.shade400,
          ),
        );
      } on BookingConflictException catch (e) {
        _showConflictDialog(e.conflictingBookings, maxSlots: facility.maxSlots);
      } on BookingValidationException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: GoogleFonts.montserrat()),
            backgroundColor: Colors.orange.shade400,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.montserrat()),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Widget _buildScheduleView() {
    if (_selectedFacility == null || _selectedDate == null) {
      return const SizedBox.shrink();
    }
    final dayStart = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final maxSlots = _selectedFacility!.maxSlots;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('facilityId', isEqualTo: _selectedFacility!.id)
          .where('bookingDate',
              isGreaterThanOrEqualTo: dayStart, isLessThan: dayEnd)
          .orderBy('bookingDate')
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        
        // 只显示 approved 状态（预订自动通过）
        final docs = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          return status == 'approved';
        }).toList();

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All slots available!',
                          style: GoogleFonts.montserrat(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$maxSlots slots per time period',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 按时间段分组统计预订数量
        final slotCounts = <String, int>{};
        final slotDetails = <String, Map<String, dynamic>>{};
        
        for (final d in docs) {
          final data = d.data()! as Map<String, dynamic>;
          final ts = (data['bookingDate'] as Timestamp).toDate();
          final dur = data['durationHours'] as int;
          final end = ts.add(Duration(hours: dur));
          final key = '${ts.hour.toString().padLeft(2, '0')}:00-${end.hour.toString().padLeft(2, '0')}:00';
          
          slotCounts[key] = (slotCounts[key] ?? 0) + 1;
          slotDetails[key] = {'start': ts, 'end': end};
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Time slots status:',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$maxSlots slots/period',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...slotCounts.entries.map((entry) {
              final timeSlot = entry.key;
              final count = entry.value;
              final available = maxSlots - count;
              final isFull = available <= 0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isFull ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFull ? Colors.red.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFull ? Icons.event_busy : Icons.event_available,
                      color: isFull ? Colors.red.shade700 : Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        timeSlot,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFull ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isFull ? 'FULL' : '$available left',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFull ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 24),
          ],
        );
      },
    );
  }

  /// 获取预订状态信息
  _BookingStatusInfo _getStatusInfo(String status, DateTime bookingDate) {
    final isPast = bookingDate.isBefore(DateTime.now());
    
    if (isPast && status == 'approved') {
      return _BookingStatusInfo(
        label: 'COMPLETED',
        color: Colors.grey,
        icon: Icons.check_circle,
      );
    }

    switch (status.toLowerCase()) {
      case 'approved':
        return _BookingStatusInfo(
          label: 'CONFIRMED',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case 'cancelled':
        return _BookingStatusInfo(
          label: 'CANCELLED',
          color: Colors.grey,
          icon: Icons.block,
        );
      default:
        return _BookingStatusInfo(
          label: status.toUpperCase(),
          color: Colors.grey,
          icon: Icons.help_outline,
        );
    }
  }

  Widget _buildRecentTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(
          child: Text('Not signed in', style: GoogleFonts.montserrat()));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('residentId', isEqualTo: uid)
          .orderBy('bookingDate', descending: true)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: GoogleFonts.montserrat(color: Colors.red)),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No bookings yet',
                    style: GoogleFonts.montserrat(color: Colors.grey)),
                const SizedBox(height: 8),
                Text('Book a facility to get started!',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final doc = docs[i];
            final data = doc.data()! as Map<String, dynamic>;
            final facName =
                _facilityNames[data['facilityId'] as String] ?? 'Unknown';
            final ts = (data['bookingDate'] as Timestamp).toDate();
            final dur = data['durationHours'] as int;
            final end = ts.add(Duration(hours: dur));
            final status = (data['status'] as String? ?? '');
            final statusInfo = _getStatusInfo(status, ts);

            final canCancel = _bookingService.canCancel(data);
            final canReschedule = _bookingService.canReschedule(data);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: statusInfo.color, width: 4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 设施名称 + 状态
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              facName,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusInfo.icon,
                                    size: 14, color: statusInfo.color),
                                const SizedBox(width: 4),
                                Text(
                                  statusInfo.label,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusInfo.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 日期时间
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(ts),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${ts.hour.toString().padLeft(2, '0')}:00 - ${end.hour.toString().padLeft(2, '0')}:00',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),

                      // 操作按钮
                      if (canCancel || canReschedule) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (canReschedule)
                              TextButton.icon(
                                icon: Icon(Icons.edit_calendar,
                                    size: 18, color: Colors.blue.shade700),
                                label: Text(
                                  'Reschedule',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onPressed: () =>
                                    _showRescheduleDialog(doc.id, data),
                              ),
                            if (canReschedule && canCancel)
                              const SizedBox(width: 8),
                            if (canCancel)
                              TextButton.icon(
                                icon: Icon(Icons.cancel_outlined,
                                    size: 18, color: Colors.red.shade700),
                                label: Text(
                                  'Cancel',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onPressed: () =>
                                    _showCancelDialog(doc.id, data),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFacilities) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Figure out if booking date is today, to filter past hours
    final now = DateTime.now();
    final isToday = _selectedDate != null &&
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;
    final nowHour = now.hour;

    // Prepare hour options, excluding past hours if booking today
    // 当前小时也不能选（需要至少提前 1 小时预订）
    final hours = _selectedFacility == null
        ? <int>[]
        : [
            for (var h = _selectedFacility!.startHour;
                h < _selectedFacility!.endHour;
                h++)
              if (!(isToday && h <= nowHour)) h
          ];

    // Duration 限制为 1 或 2 小时
    final maxDur = (_startHour != null && _selectedFacility != null)
        ? (_selectedFacility!.endHour - _startHour!).clamp(0, 2)
        : 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          centerTitle: true,
          title: Text('Facility Booking',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Book'),
              Tab(text: 'My Bookings'),
            ],
            indicatorColor: Colors.white,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).go('/user'),
          ),
        ),
        body: TabBarView(
          children: [
            // ─── Book Tab ─────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Facility>(
                    decoration: InputDecoration(
                      labelText: 'Facility',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    value: _selectedFacility,
                    items: _facilities
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child:
                                  Text(f.name, style: GoogleFonts.montserrat()),
                            ))
                        .toList(),
                    onChanged: (f) => setState(() {
                      _selectedFacility = f;
                      _selectedDate = null;
                      _startHour = null;
                      _durationHours = null;
                    }),
                  ),
                  if (_selectedFacility?.imageBase64 != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_selectedFacility!.imageBase64!),
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Pick a date'
                                  : DateFormat('dd MMM yyyy')
                                      .format(_selectedDate!),
                              style: GoogleFonts.montserrat(
                                color: _selectedDate == null
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Start Hour (only once we have hours to show)
                  if (hours.isNotEmpty)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Start Hour',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      value: _startHour,
                      items: hours
                          .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text('$h:00',
                                    style: GoogleFonts.montserrat()),
                              ))
                          .toList(),
                      onChanged: (h) => setState(() {
                        _startHour = h;
                        _durationHours = null;
                      }),
                    )
                  else
                    TextFormField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Start Hour',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        hintText: _selectedFacility == null
                            ? 'Select facility first'
                            : 'Pick a date first',
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_startHour != null)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Duration (hours)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      value: _durationHours,
                      items: List.generate(maxDur, (i) => i + 1)
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d hour${d > 1 ? 's' : ''}',
                                    style: GoogleFonts.montserrat()),
                              ))
                          .toList(),
                      onChanged: (d) => setState(() => _durationHours = d),
                    ),
                  const SizedBox(height: 24),
                  _buildScheduleView(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.montserrat(
                                  color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Submit Booking',
                              style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // ─── My Bookings Tab ───────────────────────────────────
            _buildRecentTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 2, // Facility
          selectedItemColor: Colors.red.shade700,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          onTap: (i) {
            switch (i) {
              case 0:
                GoRouter.of(context).go('/user');
                break;
              case 1:
                _showEntryDialog();
                break;
              case 2:
                // already here
                break;
              case 3:
                GoRouter.of(context).go('/user/maintenanceRequest');
                break;
              case 4:
                GoRouter.of(context).go('/userprofile');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_add), label: 'Visitor'),
            BottomNavigationBarItem(
                icon: Icon(Icons.event_available), label: 'Facility'),
            BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// 预订状态信息辅助类
class _BookingStatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  _BookingStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
