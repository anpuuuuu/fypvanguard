// lib/admin/analytics.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  Future<int> _getCount(String coll, {Map<String, dynamic>? filter}) async {
    Query q = FirebaseFirestore.instance.collection(coll);
    if (filter != null) {
      filter.forEach((k, v) => q = q.where(k, isEqualTo: v));
    }
    final snap = await q.get();
    return snap.docs.length;
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
        title: Text('Analytics & Reports',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}), // reload counts & streams
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // Stat cards grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _StatCard(
                    label: 'Owners',
                    icon: Icons.home,
                    color: Colors.blue,
                    collection: 'accounts',
                    filter: {'role': 'owner'},
                    getCount: _getCount,
                  ),
                  _StatCard(
                    label: 'Tenants',
                    icon: Icons.apartment,
                    color: Colors.green,
                    collection: 'accounts',
                    filter: {'role': 'tenant'},
                    getCount: _getCount,
                  ),
                  _StatCard(
                    label: 'Pending Visitors',
                    icon: Icons.person_add,
                    color: Colors.orange,
                    collection: 'visitors',
                    filter: {'status': 'pending'},
                    getCount: _getCount,
                  ),
                  _StatCard(
                    label: 'Pending Bookings',
                    icon: Icons.event_available,
                    color: Colors.purple,
                    collection: 'bookings',
                    filter: {'status': 'pending'},
                    getCount: _getCount,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text('Recent Visitors',
                  style: GoogleFonts.montserrat(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // Recent visitor requests
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('visitors')
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                        child: Text('No recent visitor requests.',
                            style: GoogleFonts.montserrat(color: Colors.grey)));
                  }
                  return Column(
                    children: docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final time = (d['timestamp'] as Timestamp?)
                          ?.toDate()
                          .toLocal()
                          .toString()
                          .split('.')[0];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          leading: Icon(Icons.person, color: Colors.red.shade700),
                          title: Text(d['visitorName'] ?? 'Unknown',
                              style: GoogleFonts.montserrat()),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Entry: ${d['entryType']}',
                                  style: GoogleFonts.montserrat(fontSize: 12)),
                              Text('At: ${time ?? '—'}',
                                  style: GoogleFonts.montserrat(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/admin');
              break;
            case 1:
              GoRouter.of(context).go('/admin/ownerApprovals');
              break;
            case 2:
              GoRouter.of(context).go('/admin/userManagement');
              break;
            case 3:
              GoRouter.of(context).go('/admin/announcements');
              break;
            case 4:
              GoRouter.of(context).go('/admin/facilities');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Approvals'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Announcements'),
          BottomNavigationBarItem(icon: Icon(Icons.room_service), label: 'Facilities'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final MaterialColor color;
  final String collection;
  final Map<String, dynamic>? filter;
  final Future<int> Function(String,
      {Map<String, dynamic>? filter}) getCount;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.collection,
    this.filter,
    required this.getCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<int>(
          future: getCount(collection, filter: filter),
          builder: (ctx, snap) {
            final count = snap.hasData ? snap.data! : 0;
            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.shade100,
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(count.toString(),
                          style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      const SizedBox(height: 4),
                      Text(label,
                          style: GoogleFonts.montserrat(
                              color: Colors.grey[700], fontSize: 14)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
