// lib/user/feedback_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({Key? key}) : super(key: key);
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('feedback').add({
      'userId': user.uid,
      'fullName': user.email!.split('@').first,
      'createdAt': FieldValue.serverTimestamp(),
      'message': _ctrl.text.trim(),
      'readBy': false,
    });
    _ctrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Thank you for your feedback!', style: GoogleFonts.montserrat())),
    );
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildFeedbackList() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Center(child: Text('Please log in to view feedback.', style: GoogleFonts.montserrat()));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text('No feedback submitted yet.', style: GoogleFonts.montserrat(color: Colors.grey)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data()! as Map<String, dynamic>;
            final read = d['readBy'] as bool? ?? false;
            final ts = (d['createdAt'] as Timestamp?)?.toDate().toLocal();
            final time = ts == null
                ? ''
                : '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

            return Card(
              color: read ? null : Colors.yellow.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: ListTile(
                title: Text(d['message'] ?? '', style: GoogleFonts.montserrat()),
                subtitle: Text(time, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
                trailing: read
                    ? null
                    : Icon(Icons.mark_email_read, color: Colors.red.shade700),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        title: Text('Feedback', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Write Feedback'),
            Tab(text: 'My Feedbacks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ctrl,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter some feedback' : null,
                      decoration: InputDecoration(
                        hintText: 'How can we improve?',
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red.shade700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                      onPressed: _submitting ? null : _send,
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Submit', style: GoogleFonts.montserrat(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFeedbackList(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(ctx).go('/user');
              break;
            case 1:
              GoRouter.of(ctx).push('/user/registerVisitor?type=walk-in');
              break;
            case 2:
              GoRouter.of(ctx).go('/user/bookFacility');
              break;
            case 3:
              GoRouter.of(ctx).go('/user/maintenanceRequest');
              break;
            case 4:
              GoRouter.of(ctx).go('/userprofile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Visitor'),
          BottomNavigationBarItem(icon: Icon(Icons.event_available), label: 'Facility'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
