// lib/security/feedback_inbox.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class FeedbackInboxPage extends StatelessWidget {
  const FeedbackInboxPage({Key? key}) : super(key: key);

  Future<void> _markRead(String id) =>
      FirebaseFirestore.instance.collection('feedback').doc(id).update({'readBy': true});

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        title: Text('Feedback Inbox', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(ctx).go('/security'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedback')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No feedback yet.', style: GoogleFonts.montserrat(color: Colors.grey)));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i].data()! as Map<String, dynamic>;
              final read = d['readBy'] as bool? ?? false;
              final ts = (d['createdAt'] as Timestamp?)?.toDate().toLocal();
              final time = ts == null ? '' : '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')} ${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}';

              return Card(
                color: read ? null : Colors.yellow.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
                child: ListTile(
                  title: Text(d['fullName'] ?? 'Guest', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(d['message'] ?? '', style: GoogleFonts.montserrat()),
                      const SizedBox(height: 6),
                      Text(time, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: read
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.mark_email_read, color: Colors.red),
                    onPressed: () => _markRead(docs[i].id),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4, // adjust index for “Feedback” tile
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(ctx).go('/security');
              break;
            case 1:
              GoRouter.of(ctx).go('/security/visitorApproval');
              break;
            case 2:
              GoRouter.of(ctx).go('/security/visitorTracking');
              break;
            case 3:
              GoRouter.of(ctx).go('/security/bookingApproval');
              break;
            case 4:
              GoRouter.of(ctx).go('/security/maintenanceReview');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Visitors'),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.event_available), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
        ],
      ),
    );
  }
}
