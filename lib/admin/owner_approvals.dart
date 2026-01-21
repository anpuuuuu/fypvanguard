// lib/admin/owner_approvals.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OwnerApprovalsPage extends StatefulWidget {
  const OwnerApprovalsPage({Key? key}) : super(key: key);

  @override
  _OwnerApprovalsPageState createState() => _OwnerApprovalsPageState();
}

class _OwnerApprovalsPageState extends State<OwnerApprovalsPage> {
  Future<void> _approve(String id) =>
      FirebaseFirestore.instance.collection('accounts').doc(id).update({'status': 'approved'});

  Future<void> _reject(String id) =>
      FirebaseFirestore.instance.collection('accounts').doc(id).update({'status': 'rejected'});

  Future<Map<String, dynamic>?> _fetchResident(String resId) async {
    final doc = await FirebaseFirestore.instance.collection('residents').doc(resId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Owner Approvals',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('accounts')
              .where('role', isEqualTo: 'owner')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}', style: GoogleFonts.montserrat()));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Text('No pending owner approvals.',
                    style: GoogleFonts.montserrat(color: Colors.grey)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final acc = docs[i];
                final data = acc.data()! as Map<String, dynamic>;
                final resId = data['residentId'] as String?;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['username'] ?? '—',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              if (resId != null)
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: _fetchResident(resId),
                                  builder: (ctx2, fb) {
                                    if (fb.connectionState == ConnectionState.waiting) {
                                      return Text('Loading...', style: GoogleFonts.montserrat());
                                    }
                                    final resident = fb.data;
                                    final name = resident?['fullName'] ?? '—';
                                    final unit = resident?['unitNumber'] ?? '—';
                                    return Text(
                                      '$name • Unit $unit',
                                      style: GoogleFonts.montserrat(color: Colors.grey[700]),
                                    );
                                  },
                                ),
                              const SizedBox(height: 12),
                              // Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24)),
                                      ),
                                      onPressed: () => _approve(acc.id),
                                      child: Text('Approve',
                                          style: GoogleFonts.montserrat(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24)),
                                      ),
                                      onPressed: () => _reject(acc.id),
                                      child: Text('Reject',
                                          style: GoogleFonts.montserrat(color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Proof thumbnail
                        if (resId != null)
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _fetchResident(resId),
                            builder: (ctx3, fb2) {
                              if (fb2.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                    width: 64, height: 64, child: CircularProgressIndicator());
                              }
                              final resident = fb2.data;
                              final base64Img = resident?['proofDocBase64'] as String?;
                              if (base64Img == null || base64Img.isEmpty) {
                                return Icon(Icons.insert_drive_file,
                                    size: 48, color: Colors.grey[400]);
                              }
                              final bytes = base64Decode(base64Img);
                              return GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    insetPadding: const EdgeInsets.all(16),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(bytes, fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(bytes,
                                      width: 64, height: 64, fit: BoxFit.cover),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:1, // Users tab
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
