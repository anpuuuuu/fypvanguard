// lib/admin/analytics.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Future<int> _getCount(String coll, {Map<String, dynamic>? filter, DateTimeRange? dateRange}) async {
    Query q = FirebaseFirestore.instance.collection(coll);
    if (filter != null) {
      filter.forEach((k, v) => q = q.where(k, isEqualTo: v));
    }
    if (dateRange != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start));
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end.add(const Duration(days: 1))));
    }
    final snap = await q.get();
    return snap.docs.length;
  }

  Future<Map<String, int>> _getDailyCounts(String collection, DateTimeRange range) async {
    final Map<String, int> counts = {};
    final days = range.end.difference(range.start).inDays;
    
    for (int i = 0; i <= days; i++) {
      final date = range.start.add(Duration(days: i));
      final dayKey = DateFormat('MMM d').format(date);
      counts[dayKey] = 0;
    }
    
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range.end.add(const Duration(days: 1))))
        .get();
    
    for (var doc in snap.docs) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final date = createdAt.toDate();
        final dayKey = DateFormat('MMM d').format(date);
        counts[dayKey] = (counts[dayKey] ?? 0) + 1;
      }
    }
    
    return counts;
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
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date range selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                          initialDateRange: _range,
                        );
                        if (picked != null) {
                          setState(() => _range = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${DateFormat('MMM d, yyyy').format(_range.start)} - ${DateFormat('MMM d, yyyy').format(_range.end)}',
                              style: GoogleFonts.montserrat(),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Overview statistics
              Text(
                'Overview',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _StatCard(
                    label: 'Total Users',
                    icon: Icons.people,
                    color: Colors.blue,
                    collection: 'accounts',
                    getCount: _getCount,
                    dateRange: null,
                  ),
                  _StatCard(
                    label: 'Owners',
                    icon: Icons.home,
                    color: Colors.blue.shade700,
                    collection: 'accounts',
                    filter: {'role': 'owner'},
                    getCount: _getCount,
                    dateRange: null,
                  ),
                  _StatCard(
                    label: 'Tenants',
                    icon: Icons.apartment,
                    color: Colors.green,
                    collection: 'accounts',
                    filter: {'role': 'tenant'},
                    getCount: _getCount,
                    dateRange: null,
                  ),
                  _StatCard(
                    label: 'Security',
                    icon: Icons.security,
                    color: Colors.orange,
                    collection: 'accounts',
                    filter: {'role': 'security'},
                    getCount: _getCount,
                    dateRange: null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Activity statistics
              Text(
                'Activity (Selected Period)',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _StatCard(
                    label: 'New Visitors',
                    icon: Icons.person_add,
                    color: Colors.orange,
                    collection: 'visitors',
                    getCount: _getCount,
                    dateRange: _range,
                  ),
                  _StatCard(
                    label: 'Bookings',
                    icon: Icons.event_available,
                    color: Colors.purple,
                    collection: 'bookings',
                    getCount: _getCount,
                    dateRange: _range,
                  ),
                  _StatCard(
                    label: 'Maintenance',
                    icon: Icons.build,
                    color: Colors.red,
                    collection: 'maintenanceRequests',
                    getCount: _getCount,
                    dateRange: _range,
                  ),
                  _StatCard(
                    label: 'Feedback',
                    icon: Icons.feedback,
                    color: Colors.teal,
                    collection: 'feedback',
                    getCount: _getCount,
                    dateRange: _range,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Status breakdown
              Text(
                'Status Breakdown',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatusCard(
                      label: 'Pending Visitors',
                      count: 0,
                      color: Colors.orange,
                      collection: 'visitors',
                      filter: {'status': 'pending'},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusCard(
                      label: 'Pending Bookings',
                      count: 0,
                      color: Colors.purple,
                      collection: 'bookings',
                      filter: {'status': 'pending'},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatusCard(
                      label: 'Active Maintenance',
                      count: 0,
                      color: Colors.blue,
                      collection: 'maintenanceRequests',
                      filter: {'status': 'in_progress'},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusCard(
                      label: 'Resolved',
                      count: 0,
                      color: Colors.green,
                      collection: 'maintenanceRequests',
                      filter: {'status': 'resolved'},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Recent activity
              Text(
                'Recent Activity',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 12),
              
              // Recent visitors
              _RecentActivitySection(
                title: 'Recent Visitors',
                icon: Icons.person_add,
                color: Colors.orange,
                collection: 'visitors',
                fieldName: 'visitorName',
              ),
              const SizedBox(height: 16),
              
              // Recent bookings
              _RecentActivitySection(
                title: 'Recent Bookings',
                icon: Icons.event_available,
                color: Colors.purple,
                collection: 'bookings',
                fieldName: 'facilityName',
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
  final Color color;
  final String collection;
  final Map<String, dynamic>? filter;
  final DateTimeRange? dateRange;
  final Future<int> Function(String,
      {Map<String, dynamic>? filter, DateTimeRange? dateRange}) getCount;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.collection,
    this.filter,
    this.dateRange,
    required this.getCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FutureBuilder<int>(
        future: getCount(collection, filter: filter, dateRange: dateRange),
        builder: (ctx, snap) {
          final count = snap.hasData ? snap.data! : 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String collection;
  final Map<String, dynamic> filter;

  const _StatusCard({
    required this.label,
    required this.count,
    required this.color,
    required this.collection,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(filter.keys.first, isEqualTo: filter.values.first)
          .snapshots(),
      builder: (context, snapshot) {
        final actualCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actualCount.toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String collection;
  final String fieldName;

  const _RecentActivitySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.collection,
    required this.fieldName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(collection)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: GoogleFonts.montserrat(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => Divider(color: Colors.grey[200]),
                itemBuilder: (ctx, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final name = d[fieldName] ?? 'Unknown';
                  final ts = d['createdAt'] as Timestamp?;
                  final time = ts == null
                      ? ''
                      : DateFormat('MMM d, h:mm a').format(ts.toDate().toLocal());
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      name.toString(),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      time,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
