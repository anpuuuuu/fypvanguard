// lib/security/maintenance_review.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/maintenance_service.dart';

class MaintenanceReviewPage extends StatefulWidget {
  const MaintenanceReviewPage({Key? key}) : super(key: key);

  @override
  _MaintenanceReviewPageState createState() => _MaintenanceReviewPageState();
}

class _MaintenanceReviewPageState extends State<MaintenanceReviewPage> {
  final _service = MaintenanceService();
  String _search = '';
  String _filterStatus = 'All'; // All, created, in_progress, resolved

  Future<Map<String, String>> _fetchResident(String rid) async {
    final doc = await FirebaseFirestore.instance
        .collection('residents')
        .doc(rid)
        .get();
    if (!doc.exists) return {'fullName': 'Unknown', 'unit': 'Unknown'};
    final d = doc.data()!;
    return {
      'fullName': d['fullName'] as String? ?? 'Unknown',
      'unit': d['unitNumber'] as String? ?? 'Unknown',
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
    return s == _filterStatus;
  }



  @override
  Widget build(BuildContext context) {
    final statuses = ['All', 'created' ,'in_progress', 'resolved'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Review Maintenance',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search description',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),

            // Status filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: statuses.map((st) {
                  return FilterChip(
                    label: Text(
                      st == 'All' ? st : st.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.montserrat(),
                    ),
                    selected: _filterStatus == st,
                    onSelected: (_) => setState(() => _filterStatus = st),
                  );
                }).toList(),
              ),
            ),

            const Divider(height: 32),

            // Stream of maintenance requests
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('maintenanceRequests')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                      child: Text('Error: ${snap.error}',
                          style: GoogleFonts.montserrat()));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;

                // client-side search + filter
                final list = docs.where((doc) {
                  final d = doc.data()! as Map<String, dynamic>;
                  final desc = (d['description'] as String? ?? '').toLowerCase();
                  final status = (d['status'] as String? ?? '');
                  return desc.contains(_search) && _statusAllowed(status);
                }).toList();

                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('No matching requests',
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
                    final d = doc.data()! as Map<String, dynamic>;
                    final mid = doc.id;
                    final ts = d['createdAt'] as Timestamp?;
                    final rel = _relativeTime(ts);
                    final base64 = d['imageBase64'] as String?;
                    final status = d['status'] as String? ?? 'created';

                    // choose button
                    Widget action;
                    if (status == 'created') {
                      action = ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700),
                        child: Text('In Progress',
                            style: GoogleFonts.montserrat(color: Colors.white)),
                        onPressed: () {
                          _service.updateRequestStatus(mid, 'in_progress');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked In Progress')),
                          );
                        },
                      );
                    } else if (status == 'in_progress') {
                      action = ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: Text('Resolve', style: GoogleFonts.montserrat(color: Colors.white)),
                        onPressed: () {
                          _service.updateRequestStatus(mid, 'resolved');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked Resolved')),
                          );
                        },
                      );
                    } else {
                      action = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Resolved', style: TextStyle(color: Colors.green)),
                        ],
                      );
                    }

                    return FutureBuilder<Map<String, String>>(
                      future: _fetchResident(d['residentId'] as String? ?? ''),
                      builder: (ctx2, fb) {
                        final res = fb.data ?? {'fullName': '…', 'unit': '…'};
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      res['fullName']! + ' (Unit ${res['unit']})',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(rel,
                                      style: GoogleFonts.montserrat(
                                          fontSize: 12, color: Colors.grey[600])),
                                ]),
                                const SizedBox(height: 8),
                                Text(
                                  d['description'] as String? ?? '–',
                                  style: GoogleFonts.montserrat(),
                                ),
                                if (base64 != null) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        insetPadding: const EdgeInsets.all(8),
                                        child: Image.memory(
                                          base64Decode(base64),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    child: Image.memory(
                                      base64Decode(base64),
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(alignment: Alignment.centerRight, child: action),
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
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4, // “Maintenance Review” is index 4
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
