// lib/security/security_home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vanguardfyp/services/notification_service.dart';

import 'visitor_approval.dart';
import 'visitor_tracking.dart';
import 'booking_approval.dart';
import 'maintenance_review.dart';

class SecurityHome extends StatefulWidget {
  const SecurityHome({Key? key}) : super(key: key);

  @override
  _SecurityHomeState createState() => _SecurityHomeState();
}

class _SecurityHomeState extends State<SecurityHome> {
  int _currentIndex = 0;
  late final String _role;

  @override
  void initState() {
    super.initState();
    _role = 'security'; // for filtering announcements
  }

  void _onNavTap(int idx) {
    if (idx == 0) {
      setState(() => _currentIndex = 0);
    } else {
      switch (idx) {
        case 1:
          GoRouter.of(context).go('/security/qrScanner');  // 改为 QR 扫描
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
    }
  }

  Future<void> _logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationService().removeTokenOnLogout(user.uid);
    }
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // stats streams
    final visitorStream = FirebaseFirestore.instance
        .collection('visitors')
        .where('status', isEqualTo: 'pending')
        .snapshots();
    final bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .snapshots();
    final maintenanceStream = FirebaseFirestore.instance
        .collection('maintenanceRequests')
        .where('status', isEqualTo: 'in_progress')
        .snapshots();

    // dynamic announcements stream: only those where audience contains 'security' or 'all'
    final announcementsStream = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .where('audience', arrayContainsAny: [_role, 'all'])
        .snapshots();

    // display name
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.email
        ?.split('@')
        .first
        .replaceFirstMapped(RegExp(r'^\w'),
            (m) => m.group(0)!.toUpperCase()) ??
        'Officer';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Security Dashboard',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1) Announcements carousel
            SizedBox(
              height: 80,
              child: StreamBuilder<QuerySnapshot>(
                stream: announcementsStream,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No announcements.',
                        style: GoogleFonts.montserrat(color: Colors.grey),
                      ),
                    );
                  }
                  return PageView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data()! as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Card(
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: Center(
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                data['content'] as String? ?? '',
                                style: GoogleFonts.montserrat(
                                    fontSize: 14, color: Colors.grey[800]),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 2) Greeting banner
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.red.shade700,
                    child: const Icon(Icons.security, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Hello, $displayName',
                    style: GoogleFonts.montserrat(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // 3) Quick stats
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 80,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    switch (idx) {
                      case 0:
                        return _StatCard(
                          icon: Icons.person,
                          label: 'Visitors',
                          stream: visitorStream,
                        );
                      case 1:
                        return _StatCard(
                          icon: Icons.event,
                          label: 'Bookings',
                          stream: bookingStream,
                        );
                      default:
                        return _StatCard(
                          icon: Icons.build,
                          label: 'Maintenance',
                          stream: maintenanceStream,
                        );
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4) Action grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _ActionCard(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan QR Code',
                      onTap: () =>
                          GoRouter.of(context).go('/security/qrScanner'),
                    ),
                    _ActionCard(
                      icon: Icons.how_to_reg,
                      label: 'Approve Car Visitors',
                      onTap: () =>
                          GoRouter.of(context).go('/security/visitorApproval'),
                    ),
                    _ActionCard(
                      icon: Icons.person_pin,
                      label: 'Visitor Tracking',
                      onTap: () => GoRouter.of(context)
                          .go('/security/visitorTracking'),
                    ),
                    _ActionCard(
                      icon: Icons.event_available,
                      label: 'Approve Bookings',
                      onTap: () =>
                          GoRouter.of(context).go('/security/bookingApproval'),
                    ),
                    _ActionCard(
                      icon: Icons.report_problem,
                      label: 'Review Maintenance',
                      onTap: () => GoRouter.of(context)
                          .go('/security/maintenanceReview'),
                    ),
                    _ActionCard(
                      icon: Icons.chat,
                      label: 'Message From Residents',
                      onTap: () => GoRouter.of(context)
                          .go('/security/chat'),
                    ),
                    _ActionCard(
                      icon: Icons.emergency,
                      label: 'Emergency',
                      onTap: () => GoRouter.of(context).go('/security/emergencyAlerts'),
                    ),
                    _ActionCard(
                      icon: Icons.feedback,
                      label: 'Feedback',
                      onTap: () => GoRouter.of(context).go('/security/feedback'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // 5) Bottom nav bar
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
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner), label: 'Scan QR'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_pin), label: 'Tracking'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_available), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<QuerySnapshot> stream;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          final count = snap.hasData ? snap.data!.docs.length : 0;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Column(
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
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                          fontSize: 12, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.red.shade50,
                child: Icon(icon, size: 32, color: Colors.red.shade700),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
