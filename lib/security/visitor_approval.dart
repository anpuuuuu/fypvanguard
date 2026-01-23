// lib/security/visitor_approval.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/qr_service.dart';

class VisitorApprovalPage extends StatefulWidget {
  const VisitorApprovalPage({Key? key}) : super(key: key);

  @override
  _VisitorApprovalPageState createState() => _VisitorApprovalPageState();
}

class _VisitorApprovalPageState extends State<VisitorApprovalPage> {
  String _searchQuery = '';
  String _filterDate = 'All'; // 'All','Today','This Week'
  final QrService _qrService = QrService();

  Future<void> _approveVisitor(String id) async {
    // 使用 QrService 审批并生成 QR 码
    await _qrService.approveVisitorAndGenerateQr(
      visitorId: id,
      entryType: 'car',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Visitor approved! QR code generated.', 
              style: GoogleFonts.montserrat()),
          backgroundColor: Colors.green.shade400,
        ),
      );
    }
  }

  Future<void> _denyVisitor(String id) async {
    await FirebaseFirestore.instance
        .collection('visitors')
        .doc(id)
        .update({'status': 'denied'});
  }

  Future<Map<String, String>> _fetchResident(String rid) async {
    final doc =
    await FirebaseFirestore.instance.collection('residents').doc(rid).get();
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
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  bool _dateAllowed(Timestamp? ts) {
    if (_filterDate == 'All') return true;
    if (ts == null) return false;
    final date = ts.toDate();
    final now = DateTime.now();
    if (_filterDate == 'Today') {
      final start = DateTime(now.year, now.month, now.day);
      return date.isAfter(start);
    }
    if (_filterDate == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      return date.isAfter(start);
    }
    return true;
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Visitor Approvals',
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // — Search bar —
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search visitor',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),

            // — 提示信息 —
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Walk-in visitors are auto-approved. Only car visitors need manual approval.',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // — Filter chips —
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Today'),
                    selected: _filterDate == 'Today',
                    onSelected: (_) => setState(() => _filterDate = 'Today'),
                  ),
                  FilterChip(
                    label: const Text('This Week'),
                    selected: _filterDate == 'This Week',
                    onSelected: (_) =>
                        setState(() => _filterDate = 'This Week'),
                  ),
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterDate == 'All',
                    onSelected: (_) => setState(() => _filterDate = 'All'),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Pending Visitor Requests',
                  style: GoogleFonts.montserrat(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),

            // — Visitor list with buttons (只显示 car 类型) —
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('status', isEqualTo: 'pending')
                  .where('entryType', isEqualTo: 'car')  // 只显示 car 访客
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  // search
                  final name =
                  (d['visitorName'] as String? ?? '').toLowerCase();
                  if (_searchQuery.isNotEmpty &&
                      !name.contains(_searchQuery)) return false;
                  // date filter
                  final ts = d['createdAt'] as Timestamp?;
                  if (!_dateAllowed(ts)) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No matching requests.',
                          style:
                          GoogleFonts.montserrat(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final vid = doc.id;
                    final entryType = (d['entryType'] as String?) ?? '';
                    final borderColor = Colors.red.shade700;  // 只有 car 类型
                    final relTime = _relativeTime(d['createdAt'] as Timestamp?);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(color: borderColor, width: 4)),
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
                                  Text(relTime,
                                      style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // resident info
                              FutureBuilder<Map<String, String>>(
                                future: _fetchResident(
                                    d['residentId'] as String? ?? ''),
                                builder: (ctx2, rs) {
                                  final res = rs.data ??
                                      {'fullName': '…', 'unit': '…'};
                                  return Text(
                                    'Resident: ${res['fullName']}, Unit ${res['unit']}',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 14),
                                  );
                                },
                              ),

                              // entry, plate, phone, *duration*
                              Text(
                                'Entry: ${entryType.toUpperCase()}',
                                style:
                                GoogleFonts.montserrat(fontSize: 14),
                              ),
                              if (entryType.toLowerCase() == 'car') ...[
                                Text(
                                  'Plate: ${d['vehiclePlate'] ?? 'N/A'}',
                                  style:
                                  GoogleFonts.montserrat(fontSize: 14),
                                ),
                                Text(
                                  'Duration: ${d['parkingDuration'] ?? 'N/A'}',
                                  style:
                                  GoogleFonts.montserrat(fontSize: 14),
                                ),
                              ],
                              Text(
                                'Phone: ${d['phoneNumber'] ?? '–'}',
                                style:
                                GoogleFonts.montserrat(fontSize: 14),
                              ),

                              // 停车规则提示
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.timer, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Max 4h parking, must leave by 2 AM',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // buttons row
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    label: Text('Approve',
                                        style: GoogleFonts.montserrat(
                                            color: Colors.green)),
                                    onPressed: () => _approveVisitor(vid),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    label: Text('Deny',
                                        style: GoogleFonts.montserrat(
                                            color: Colors.red)),
                                    onPressed: () => _denyVisitor(vid),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),

      // bottom nav
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
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
          BottomNavigationBarItem(
              icon: Icon(Icons.build), label: 'Review'),
        ],
      ),
    );
  }
}