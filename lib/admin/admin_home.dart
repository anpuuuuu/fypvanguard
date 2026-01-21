// lib/admin/admin_home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final res = await FirebaseFirestore.instance
        .collection('residents')
        .doc(uid)
        .get();
    final name = res.data()?['fullName'] as String?;
    if (name != null && name.isNotEmpty) {
      setState(() => _adminName = name);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Admin Dashboard',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SafeArea(
          bottom: true,
          child: ListView(
            padding: EdgeInsets.only(
              bottom: kBottomNavigationBarHeight + 32, // extra padding
            ),
            children: [
              // Greeting
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Hello, $_adminName',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Stats
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('accounts')
                          .where('role', isEqualTo: 'owner')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (ctx, snap) {
                        final count =
                        snap.hasData ? snap.data!.docs.length : 0;
                        return _MiniStatCard(
                            icon: Icons.person_add,
                            label: 'Pending',
                            count: count);
                      },
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('accounts')
                          .snapshots(),
                      builder: (ctx, snap) {
                        final count =
                        snap.hasData ? snap.data!.docs.length : 0;
                        return _MiniStatCard(
                            icon: Icons.people,
                            label: 'Total Users',
                            count: count);
                      },
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('visitors')
                          .where('timestamp',
                          isGreaterThanOrEqualTo: todayStart)
                          .where('timestamp', isLessThan: tomorrowStart)
                          .snapshots(),
                      builder: (ctx, snap) {
                        final count =
                        snap.hasData ? snap.data!.docs.length : 0;
                        return _MiniStatCard(
                            icon: Icons.person,
                            label: 'Visitors Today',
                            count: count);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // Action Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                  children: [
                    _ActionCard(
                      icon: Icons.person_add,
                      label: 'Owner Approvals',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/ownerApprovals'),
                    ),
                    _ActionCard(
                      icon: Icons.manage_accounts,
                      label: 'User Management',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/userManagement'),
                    ),
                    _ActionCard(
                      icon: Icons.campaign,
                      label: 'Announcements',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/announcements'),
                    ),
                    _ActionCard(
                      icon: Icons.room_service,
                      label: 'Facilities',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/facilities'),
                    ),
                    _ActionCard(
                      icon: Icons.feedback,
                      label: 'Feedback',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/feedback'),
                    ),
                    _ActionCard(
                      icon: Icons.contact_emergency,
                      label: 'Emergency Contact',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/emergencyContact'),
                    ),
                    _ActionCard(
                      icon: Icons.bar_chart,
                      label: 'Analytics & Reports',
                      onTap: () =>
                          GoRouter.of(context).go('/admin/analytics'),
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:0, // Users tab
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

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.count,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700),
                  ),
                  Text(label,
                      style: GoogleFonts.montserrat(
                          fontSize: 12, color: Colors.grey[800])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade50,
                child: Icon(icon, color: Colors.red.shade700),
              ),
              const SizedBox(height: 12),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
