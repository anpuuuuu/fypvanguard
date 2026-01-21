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
  final String? imageBase64;

  Facility({
    required this.id,
    required this.name,
    required this.startHour,
    required this.endHour,
    this.imageBase64,
  });

  factory Facility.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Facility(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      startHour: data['startHour'] as int? ?? 0,
      endHour: data['endHour'] as int? ?? 24,
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
          content:
          Text('Booking requested', style: GoogleFonts.montserrat()),
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
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _submitting = false;
      });
    }
  }

  Widget _buildScheduleView() {
    if (_selectedFacility == null || _selectedDate == null) {
      return const SizedBox.shrink();
    }
    final dayStart = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('facilityId', isEqualTo: _selectedFacility!.id)
          .where('status', isEqualTo: 'approved')
          .where('bookingDate',
          isGreaterThanOrEqualTo: dayStart, isLessThan: dayEnd)
          .orderBy('bookingDate')
          .limit(10)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No approved bookings that day.',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approved bookings:',
                style:
                GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...docs.map((d) {
              final data = d.data()! as Map<String, dynamic>;
              final ts = (data['bookingDate'] as Timestamp).toDate();
              final dur = data['durationHours'] as int;
              final end = ts.add(Duration(hours: dur));
              final label =
                  '${ts.hour.toString().padLeft(2, '0')}:00 - ${end.hour.toString().padLeft(2, '0')}:00';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $label',
                    style: GoogleFonts.montserrat(fontSize: 14)),
              );
            }).toList(),
            const Divider(),
          ],
        );
      },
    );
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
              child: Text('No recent bookings',
                  style: GoogleFonts.montserrat(color: Colors.grey)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (c, i) {
            final data = docs[i].data()! as Map<String, dynamic>;
            final facName =
                _facilityNames[data['facilityId'] as String] ?? 'Unknown';
            final ts = (data['bookingDate'] as Timestamp).toDate();
            final dur = data['durationHours'] as int;
            final end = ts.add(Duration(hours: dur));
            final timeStr =
                '${DateFormat('dd MMM yyyy').format(ts)}  •  ${ts.hour.toString().padLeft(2,'0')}:00–${end.hour.toString().padLeft(2,'0')}:00';
            final status = (data['status'] as String? ?? '').toLowerCase();
            Color clr;
            switch (status) {
              case 'approved':
                clr = Colors.green;
                break;
              case 'denied':
                clr = Colors.red;
                break;
              default:
                clr = Colors.orange;
            }
            return ListTile(
              title: Text(facName,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeStr, style: GoogleFonts.montserrat(fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Status: ${status.toUpperCase()}',
                      style: GoogleFonts.montserrat(color: clr)),
                ],
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
    final hours = _selectedFacility == null
        ? <int>[]
        : [
      for (var h = _selectedFacility!.startHour;
      h < _selectedFacility!.endHour;
      h++)
        if (!(isToday && h <= nowHour)) h
    ];

    final maxDur = (_startHour != null && _selectedFacility != null)
        ? (_selectedFacility!.endHour - _startHour!)
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
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedFacility,
                    items: _facilities
                        .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f.name,
                          style: GoogleFonts.montserrat()),
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
                    Image.memory(
                      base64Decode(_selectedFacility!.imageBase64!),
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'No date chosen'
                              : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}',
                          style: GoogleFonts.montserrat(),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDate,
                        child:
                        Text('Pick Date', style: GoogleFonts.montserrat()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
// Start Hour (only once we have hours to show)
                  if (hours.isNotEmpty)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Start Hour',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _startHour,
                      items: hours
                          .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text('$h:00', style: GoogleFonts.montserrat()),
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _durationHours,
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
                    Text(_error!, style: GoogleFonts.montserrat(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700),
                      child: _submitting
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : Text('Submit Booking',
                          style: GoogleFonts.montserrat(
                              color: Colors.white)),
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
            BottomNavigationBarItem(
                icon: Icon(Icons.build), label: 'Maintain'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
