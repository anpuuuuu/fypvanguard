// lib/security/booking_approval.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/booking_service.dart';

class BookingApprovalPage extends StatefulWidget {
  const BookingApprovalPage({Key? key}) : super(key: key);

  @override
  _BookingApprovalPageState createState() => _BookingApprovalPageState();
}

class _BookingApprovalPageState extends State<BookingApprovalPage> {
  int _currentIndex = 3; // “Bookings” tab in bottom nav

  /// Fetch resident’s name & unit
  Future<Map<String, String>> _fetchResidentInfo(String residentId) async {
    final doc = await FirebaseFirestore.instance
        .collection('residents')
        .doc(residentId)
        .get();
    final data = doc.data()!;
    return {
      'fullName': data['fullName'] as String? ?? 'Unknown',
      'unit': data['unitNumber'] as String? ?? 'Unknown',
    };
  }

  /// Fetch facility name
  Future<String> _fetchFacilityName(String facilityId) async {
    final doc = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .get();
    return doc.data()?['name'] as String? ?? facilityId;
  }

  /// Background for swipe
  Widget _buildSwipeBg({required bool approve}) {
    return Container(
      color: approve ? Colors.green : Colors.red,
      alignment: approve ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        approve ? Icons.check_circle : Icons.cancel,
        color: Colors.white,
      ),
    );
  }

  /// Confirmation dialog
  Future<bool?> _confirmDialog(
      BuildContext ctx, String title, Color color, String action) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title, style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: GoogleFonts.montserrat(color: color)),
          ),
        ],
      ),
    );
  }

  /// Handle bottom nav taps
  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        GoRouter.of(context).go('/security');
        break;
      case 1:
        GoRouter.of(context).go('/security/visitorApproval');
        break;
      case 2:
        GoRouter.of(context).go('/security/visitorTracking');
        break;
      case 3:
      // already here
        break;
      case 4:
        GoRouter.of(context).go('/security/maintenanceReview');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = BookingService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          title: Text('Booking Approvals',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).go('/security'),
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
            ],
            indicatorColor: Colors.white,
          ),
        ),

        body: TabBarView(
          children: [
            // ─── Pending bookings ──────────────────
            StreamBuilder<QuerySnapshot>(
              stream: service.streamPendingBookings(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text('No pending bookings.',
                        style: GoogleFonts.montserrat(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data()! as Map<String, dynamic>;
                    final ts = (data['bookingDate'] as Timestamp).toDate().toLocal();
                    final end = ts.add(Duration(hours: data['durationHours'] as int));
                    final dateStr = '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')}';
                    final timeStr = '${ts.hour.toString().padLeft(2,'0')}:00 - ${end.hour.toString().padLeft(2,'0')}:00';

                    return FutureBuilder<List<Object>>(
                      future: Future.wait([
                        _fetchResidentInfo(data['residentId'] as String),
                        _fetchFacilityName(data['facilityId'] as String),
                      ]),
                      builder: (ctx2, fb) {
                        if (!fb.hasData) {
                          return const ListTile(
                              title: Text('Loading…'),
                              subtitle: Text('Please wait'));
                        }
                        final residentInfo = fb.data![0] as Map<String, String>;
                        final facilityName = fb.data![1] as String;

                        return Dismissible(
                          key: ValueKey(doc.id),
                          background: _buildSwipeBg(approve: true),
                          secondaryBackground: _buildSwipeBg(approve: false),
                          confirmDismiss: (dir) async {
                            final approve = dir == DismissDirection.startToEnd;
                            final ok = await _confirmDialog(
                              context,
                              approve ? 'Approve this booking?' : 'Deny this booking?',
                              approve ? Colors.green : Colors.red,
                              approve ? 'Approve' : 'Deny',
                            );
                            if (ok == true) {
                              await service.updateBookingStatus(
                                doc.id,
                                approve ? 'approved' : 'denied',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Booking ${approve ? 'approved' : 'denied'}',
                                    style: GoogleFonts.montserrat(),
                                  ),
                                ),
                              );
                            }
                            return ok == true;
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: Icon(Icons.event_available, color: Colors.red.shade700),
                              title: Text(
                                '${residentInfo['fullName']} • Unit ${residentInfo['unit']}',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$facilityName\n$dateStr   $timeStr',
                                style: GoogleFonts.montserrat(),
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text('PENDING',
                                    style: GoogleFonts.montserrat(
                                        color: Colors.orange, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.orange.shade50,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            // ─── Approved bookings ──────────────────
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('status', isEqualTo: 'approved')
                  .orderBy('bookingDate')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text('No approved bookings.',
                        style: GoogleFonts.montserrat(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data()! as Map<String, dynamic>;
                    final ts = (data['bookingDate'] as Timestamp).toDate().toLocal();
                    final end = ts.add(Duration(hours: data['durationHours'] as int));
                    final dateStr = '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')}';
                    final timeStr = '${ts.hour.toString().padLeft(2,'0')}:00 - ${end.hour.toString().padLeft(2,'0')}:00';

                    return FutureBuilder<List<Object>>(
                      future: Future.wait([
                        _fetchResidentInfo(data['residentId'] as String),
                        _fetchFacilityName(data['facilityId'] as String),
                      ]),
                      builder: (ctx2, fb) {
                        if (!fb.hasData) {
                          return const ListTile(
                              title: Text('Loading…'),
                              subtitle: Text('Please wait'));
                        }
                        final residentInfo = fb.data![0] as Map<String, String>;
                        final facilityName = fb.data![1] as String;

                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: Icon(Icons.check_circle, color: Colors.green),
                            title: Text(
                              '${residentInfo['fullName']} • Unit ${residentInfo['unit']}',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '$facilityName\n$dateStr   $timeStr',
                              style: GoogleFonts.montserrat(),
                            ),
                            isThreeLine: true,
                            trailing: Chip(
                              label: Text('APPROVED',
                                  style: GoogleFonts.montserrat(
                                      color: Colors.green, fontWeight: FontWeight.w600)),
                              backgroundColor: Colors.green.shade50,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),

        // ─── Bottom Navigation ────────────────────
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Colors.red.shade700,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          onTap: _onNavTap,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Visitors'),
            BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Tracking'),
            BottomNavigationBarItem(icon: Icon(Icons.event_available), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
          ],
        ),
      ),
    );
  }
}
