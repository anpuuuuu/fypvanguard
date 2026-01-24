// lib/user/user_home.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vanguardfyp/services/string_extensions.dart';
import 'package:vanguardfyp/services/notification_service.dart';
import 'RegisterVisitorForm.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  UserHomeState createState() => UserHomeState();
}

class UserHomeState extends State<UserHome> {
  late final String uid;
  String? _residentId;
  String _residentName = '';
  String _role = '';
  final PageController _announcementsController = PageController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid ?? '';
    _loadResidentInfo();
  }

  Future<void> _loadResidentInfo() async {
    if (uid.isEmpty) return;

    // 1) read account
    final acctSnap = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(uid)
        .get();
    final acctData = acctSnap.data()!;
    final resId = acctData['residentId'] as String?;
    final role  = acctData['role']       as String? ?? '';
    setState(() {
      _role       = role;
      _residentId = resId;
    });

    // 2) read resident name
    if (resId != null) {
      final resSnap = await FirebaseFirestore.instance
          .collection('residents')
          .doc(resId)
          .get();
      final fullName = resSnap.data()?['fullName'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        setState(() => _residentName = fullName);
      }
    }
  }

  void _logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 移除 FCM Token
      await NotificationService().removeTokenOnLogout(user.uid);
    }
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  void _showEntryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Entry Type', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
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
                  MaterialPageRoute(builder: (_) => const RegisterVisitorForm(entryType: 'walk-in')),
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
                  MaterialPageRoute(builder: (_) => const RegisterVisitorForm(entryType: 'car')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // today range
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    // stats streams
    final visitorStream = FirebaseFirestore.instance
        .collection('visitors')
        .where('residentId', isEqualTo: _residentId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
        .snapshots();
    final bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('residentId', isEqualTo: _residentId)
        .where('bookingDate', isGreaterThanOrEqualTo: todayStart)
        .where('bookingDate', isLessThan: tomorrowStart)
        .snapshots();
    final maintenanceStream = FirebaseFirestore.instance
        .collection('maintenanceRequests')
        .where('residentId', isEqualTo: _residentId)
        .where('status', isEqualTo: 'in_progress')
        .snapshots();

    // announcements stream: only those whose audience array contains this role or “all”
    final announcementsStream = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .where('audience', arrayContainsAny: [_role, 'all'])
        .snapshots();

    final displayName = _residentName.isNotEmpty
        ? _residentName
        : (FirebaseAuth.instance.currentUser?.email
        ?.split('@')
        .first
        .capitalize() ??
        'Resident');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.red.shade700,
              child: Text(
                displayName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $displayName',
                    style: GoogleFonts.montserrat(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Welcome back!',
                    style: GoogleFonts.montserrat(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.grey[700],
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // 1) Announcements Carousel
              SizedBox(
                height: 100,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('announcements')
                      .orderBy('createdAt', descending: true)
                      .where('audience', arrayContainsAny: [_role, 'all'])
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      // show the Firestore error
                      return Center(
                        child: Text(
                          'Error loading announcements:\n${snap.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(color: Colors.red),
                        ),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No announcements.',
                          style: GoogleFonts.montserrat(color: Colors.grey),
                        ),
                      );
                    }
                    return PageView.builder(
                      controller: _announcementsController,
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data()! as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Card(
                            color: Colors.red.shade50,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                data['content'] as String? ?? '',
                                style: GoogleFonts.montserrat(
                                    fontSize: 14, color: Colors.grey[800]),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),


              const SizedBox(height: 8),

              // 2) Quick Stats Strip
              SizedBox(
                height: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _MiniStatCard(
                          icon: Icons.event_available,
                          label: 'Today Facility',
                          countStream: bookingStream),
                      const SizedBox(width: 12),
                      _MiniStatCard(
                          icon: Icons.build_circle,
                          label: 'In-Progress',
                          countStream: maintenanceStream),
                    ],
                  ),
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Divider(thickness: 1),
              ),

              // 3) Action Grid
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
                        label: 'Visitor',
                        onTap: _showEntryDialog),
                    _ActionCard(
                        icon: Icons.event_available,
                        label: 'Facility',
                        onTap: () =>
                            GoRouter.of(context).go('/user/bookFacility')),
                    _ActionCard(
                        icon: Icons.build,
                        label: 'Maintenance',
                        onTap: () =>
                            GoRouter.of(context).go('/user/maintenanceRequest')),
                    _ActionCard(
                        icon: Icons.chat,
                        label: 'Chat with Security',
                        onTap: () =>
                            GoRouter.of(context).go('/user/chat')),
                    _ActionCard(
                        icon: Icons.forum,
                        label: 'Resident Forum',
                        onTap: () =>
                            GoRouter.of(context).go('/groupchat')),
                    _ActionCard(
                        icon: Icons.emergency,
                        label: 'Emergency',
                        onTap: () =>
                            GoRouter.of(context).go('/user/emergency')),
                    if (_role == 'owner')
                      _ActionCard(
                          icon: Icons.apartment,
                          label: 'My Tenant',
                          onTap: () =>
                              GoRouter.of(context).go('/mytenant')),
                    _ActionCard(
                      icon: Icons.feedback,
                      label: 'Feedback',
                      onTap: () => GoRouter.of(context).go('/user/feedback'),
                    ),
                    _ActionCard(
                      icon: Icons.payment,
                      label: 'Payment',
                      onTap: () => GoRouter.of(context).go('/user/payment'),
                    ),
                    _ActionCard(
                        icon: Icons.person,
                        label: 'Profile',
                        onTap: () =>
                            GoRouter.of(context).go('/userprofile')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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
              GoRouter.of(context).go('/user/bookFacility');
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
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<QuerySnapshot> countStream;
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.countStream,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: StreamBuilder<QuerySnapshot>(
        stream: countStream,
        builder: (context, snap) {
          final count = snap.hasData ? snap.data!.docs.length : 0;
          return Container(
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
                      Text('$count',
                          style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700)),
                      Text(label,
                          style: GoogleFonts.montserrat(
                              fontSize: 12, color: Colors.grey[800])),
                    ],
                  ),
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
              const SizedBox(height: 8),
              Text(label,
                  style: GoogleFonts.montserrat(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
