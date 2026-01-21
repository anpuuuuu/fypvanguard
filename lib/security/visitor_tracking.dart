// lib/security/visitor_tracking.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class VisitorTrackingPage extends StatefulWidget {
  const VisitorTrackingPage({Key? key}) : super(key: key);

  @override
  _VisitorTrackingPageState createState() => _VisitorTrackingPageState();
}

class _VisitorTrackingPageState extends State<VisitorTrackingPage> {
  String _search = '';
  String _filterStatus = 'All'; // All, Approved, Checked-In, Checked-Out

  Future<void> _changeStatus(String id, String status) =>
      FirebaseFirestore.instance.collection('visitors').doc(id).update({
        'status': status,
      });

  Future<Map<String, String>> _residentInfo(String rid) async {
    final doc = await FirebaseFirestore.instance.collection('residents').doc(rid).get();
    final data = doc.data() ?? {};
    return {
      'fullName': data['fullName'] as String? ?? 'Unknown',
      'unit': data['unitNumber'] as String? ?? 'Unknown',
    };
  }

  String _relativeTime(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _statusAllowed(String s) {
    if (_filterStatus == 'All') return true;
    return s == _filterStatus.toLowerCase();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.email
        ?.split('@')
        .first
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase()) ??
        'Officer';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Visitor Tracking',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(padding: EdgeInsets.zero, children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or unit',
                prefixIcon: const Icon(Icons.search),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),

          // Status filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, children: [
              for (final label in ['All', 'Approved', 'Checked-In', 'Checked-Out'])
                FilterChip(
                  label: Text(label),
                  selected: _filterStatus == label,
                  onSelected: (_) => setState(() => _filterStatus = label),
                )
            ]),
          ),

          const Divider(height: 32),

          // Stream of all visitors
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('visitors')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];

              // Client-side filtering
              final list = docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = (d['visitorName'] as String? ?? '').toLowerCase();
                final status = (d['status'] as String? ?? '').toLowerCase();
                return name.contains(_search) && _statusAllowed(status);
              }).toList();

              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text('No matching visitors',
                          style: GoogleFonts.montserrat(color: Colors.grey))),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final doc = list[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final vid = doc.id;
                  final entryType = d['entryType'] as String? ?? '';
                  final borderColor = entryType == 'car'
                      ? Colors.red.shade700
                      : Colors.blue.shade700;
                  final rel = _relativeTime(d['timestamp'] as Timestamp?);

                  // determine next action
                  String btnText;
                  VoidCallback? onTap;
                  switch ((d['status'] as String? ?? '').toLowerCase()) {
                    case 'approved':
                      btnText = 'Check In';
                      onTap = () => _changeStatus(vid, 'checked-in');
                      break;
                    case 'checked-in':
                      btnText = 'Check Out';
                      onTap = () => _changeStatus(vid, 'checked-out');
                      break;
                    case 'checked-out':
                      btnText = 'Completed';
                      onTap = null;
                      break;
                    default:
                      btnText = d['status']?.toString() ?? '';
                      onTap = null;
                  }

                  return FutureBuilder<Map<String, String>>(
                    future:
                    _residentInfo(d['residentId'] as String? ?? ''),
                    builder: (ctx2, rSnap) {
                      final res =
                          rSnap.data ?? {'fullName': '…', 'unit': '…'};
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  color: borderColor, width: 4)),
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // top row: name + time
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      d['visitorName'] as String? ?? '–',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(rel,
                                      style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Resident: ${res['fullName']}',
                                  style:
                                  GoogleFonts.montserrat(fontSize: 14)),
                              Text('Unit: ${res['unit']}',
                                  style:
                                  GoogleFonts.montserrat(fontSize: 14)),
                              Text('Type: ${entryType.toUpperCase()}',
                                  style:
                                  GoogleFonts.montserrat(fontSize: 14)),
                              if (entryType.toLowerCase() == 'car') ...[
                                Text(
                                  'Plate: ${d['vehiclePlate'] as String? ?? 'N/A'}',
                                  style: GoogleFonts.montserrat(fontSize: 14),
                                ),
                                // <-- new parking duration line:
                                Text(
                                  'Duration: ${d['parkingDuration'] as String? ?? 'N/A'}',
                                  style: GoogleFonts.montserrat(fontSize: 14),
                                ),
                              ],
                              Text('Phone: ${d['phoneNumber'] as String? ?? '–'}',
                                  style:
                                  GoogleFonts.montserrat(fontSize: 14)),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: onTap,
                                  child: Text(btnText,
                                      style:
                                      GoogleFonts.montserrat()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Tracking is index 2
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
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
              GoRouter.of(context).go('/security/bookingApproval');
              break;
            case 4:
              GoRouter.of(context).go('/security/maintenanceReview');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner), label: 'Approve'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_pin), label: 'Tracking'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_available), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Review'),
        ],
      ),
    );
  }
}