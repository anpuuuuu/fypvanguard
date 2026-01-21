// lib/admin/announcements_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({Key? key}) : super(key: key);

  @override
  _AdminAnnouncementsPageState createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _collection = FirebaseFirestore.instance.collection('announcements');
  final List<String> _allRoles = ['owner', 'tenant', 'security', 'all'];

  Future<void> _showEditDialog({
    String? docId,
    String initialContent = '',
    List<String>? initialAudience,
  }) async {
    final isNew = docId == null;
    final controller = TextEditingController(text: initialContent);
    // ensure we start with a List<String>
    final selected = Set<String>.from(initialAudience ?? ['all']);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            isNew ? 'New Announcement' : 'Edit Announcement',
            style: GoogleFonts.montserrat(),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Audience',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _allRoles.map((role) {
                    final isSel = selected.contains(role);
                    return FilterChip(
                      label: Text(
                        role == 'all' ? 'Everyone' : role.capitalize(),
                        style: GoogleFonts.montserrat(
                          color: isSel ? Colors.white : Colors.black,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: Theme.of(context).primaryColor,
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            if (role == 'all') {
                              selected
                                ..clear()
                                ..add('all');
                            } else {
                              selected.remove('all');
                              selected.add(role);
                            }
                          } else {
                            selected.remove(role);
                            if (selected.isEmpty) selected.add('all');
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.montserrat()),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text(isNew ? 'Create' : 'Save',
                  style: GoogleFonts.montserrat()),
              onPressed: () async {
                final content = controller.text.trim();
                if (content.isEmpty) return;
                final data = {
                  'content': content,
                  // now always a List<String>
                  'audience': selected.toList(),
                  'createdAt': FieldValue.serverTimestamp(),
                };
                if (isNew) {
                  await _collection.add(data);
                } else {
                  await _collection.doc(docId).update(data);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Announcement?', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.montserrat()),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: Text('Delete',
                style: GoogleFonts.montserrat(color: Colors.red)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _collection.doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Announcements',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
        _collection.orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('No announcements.',
                  style: GoogleFonts.montserrat(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final data = d.data()! as Map<String, dynamic>;

              // safely pull out a List<String>
              final rawAudience = data['audience'];
              final audience = rawAudience is String
                  ? <String>[rawAudience]
                  : (rawAudience is Iterable
                  ? List<String>.from(rawAudience)
                  : <String>['all']);

              final ts = data['createdAt'] as Timestamp?;
              final date = ts?.toDate().toLocal();
              final dateStr = date == null
                  ? ''
                  : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['content'] as String? ?? '',
                          style: GoogleFonts.montserrat(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(dateStr,
                          style: GoogleFonts.montserrat(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: audience.map((r) {
                          final label =
                          r == 'all' ? 'Everyone' : r.capitalize();
                          return Chip(
                            label: Text(label,
                                style: GoogleFonts.montserrat(fontSize: 12)),
                            backgroundColor: Colors.red.shade50,
                          );
                        }).toList(),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(
                              docId: d.id,
                              initialContent: data['content'] as String? ?? '',
                              initialAudience: audience,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(d.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add),
        onPressed: () => _showEditDialog(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:3, // Users tab
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

/// Simple extension to capitalize
extension StringExtension on String {
  String capitalize() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
