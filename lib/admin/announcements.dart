// lib/admin/announcements_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({Key? key}) : super(key: key);

  @override
  _AdminAnnouncementsPageState createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _collection = FirebaseFirestore.instance.collection('announcements');
  final List<String> _allRoles = ['owner', 'tenant', 'security', 'all'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterAudience = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog({
    String? docId,
    String initialContent = '',
    List<String>? initialAudience,
    String? initialPriority,
    DateTime? initialExpiry,
  }) async {
    final isNew = docId == null;
    final controller = TextEditingController(text: initialContent);
    final titleController = TextEditingController(text: '');
    // ensure we start with a List<String>
    final selected = Set<String>.from(initialAudience ?? ['all']);
    String priority = initialPriority ?? 'normal';
    DateTime? expiryDate = initialExpiry;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isNew ? 'New Announcement' : 'Edit Announcement',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.montserrat(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Content *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.montserrat(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Priority',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<String>(
                    value: priority,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['low', 'normal', 'high', 'urgent'].map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(p),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(p.capitalize(), style: GoogleFonts.montserrat()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => priority = v!),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Audience',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allRoles.map((role) {
                    final isSel = selected.contains(role);
                    return FilterChip(
                      label: Text(
                        role == 'all' ? 'Everyone' : role.capitalize(),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: isSel ? Colors.white : Colors.black,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: Colors.red.shade700,
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
                const SizedBox(height: 16),
                Text(
                  'Expiry Date (Optional)',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => expiryDate = picked);
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
                          expiryDate == null
                              ? 'No expiry date'
                              : DateFormat('MMM d, yyyy').format(expiryDate!),
                          style: GoogleFonts.montserrat(),
                        ),
                        if (expiryDate != null) ...[
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => expiryDate = null),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isNew ? 'Create' : 'Save',
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () async {
                final content = controller.text.trim();
                if (content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Content is required', style: GoogleFonts.montserrat())),
                  );
                  return;
                }
                final data = {
                  'content': content,
                  'title': titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
                  'audience': selected.toList(),
                  'priority': priority,
                  if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
                  if (isNew) 'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (isNew) {
                  await _collection.add(data);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Announcement created', style: GoogleFonts.montserrat()),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  await _collection.doc(docId).update(data);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Announcement updated', style: GoogleFonts.montserrat()),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'normal': return Colors.blue;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Manage Announcements',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Search and filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search announcements...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.montserrat(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Audience:', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: ['All', 'owner', 'tenant', 'security', 'all'].map((audience) {
                          return FilterChip(
                            label: Text(
                              audience == 'All' ? 'All' : audience == 'all' ? 'Everyone' : audience.capitalize(),
                              style: GoogleFonts.montserrat(fontSize: 11),
                            ),
                            selected: _filterAudience == audience,
                            onSelected: (_) => setState(() => _filterAudience = audience),
                            padding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Announcements list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _collection.orderBy('createdAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                
                // Filter
                final filteredDocs = docs.where((doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  final content = (data['content'] ?? '').toString().toLowerCase();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  
                  final rawAudience = data['audience'];
                  final audience = rawAudience is String
                      ? <String>[rawAudience]
                      : (rawAudience is Iterable
                      ? List<String>.from(rawAudience)
                      : <String>['all']);
                  
                  bool matchesSearch = _searchQuery.isEmpty ||
                      content.contains(_searchQuery) ||
                      title.contains(_searchQuery);
                  
                  bool matchesAudience = _filterAudience == 'All' ||
                      audience.contains(_filterAudience) ||
                      (_filterAudience == 'all' && audience.contains('all'));
                  
                  // Check expiry
                  final expiryDate = data['expiryDate'] as Timestamp?;
                  if (expiryDate != null) {
                    if (expiryDate.toDate().isBefore(DateTime.now())) {
                      return false; // Hide expired announcements
                    }
                  }
                  
                  return matchesSearch && matchesAudience;
                }).toList();
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No announcements'
                              : 'No announcements found',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, i) {
                    final d = filteredDocs[i];
                    final data = d.data()! as Map<String, dynamic>;

                    final rawAudience = data['audience'];
                    final audience = rawAudience is String
                        ? <String>[rawAudience]
                        : (rawAudience is Iterable
                        ? List<String>.from(rawAudience)
                        : <String>['all']);

                    final title = data['title'] as String?;
                    final content = data['content'] as String? ?? '';
                    final priority = data['priority'] as String? ?? 'normal';
                    final ts = data['createdAt'] as Timestamp?;
                    final expiryDate = data['expiryDate'] as Timestamp?;
                    final date = ts?.toDate().toLocal();
                    final dateStr = date == null
                        ? ''
                        : DateFormat('MMM d, yyyy h:mm a').format(date);
                    final isExpired = expiryDate != null && expiryDate.toDate().isBefore(DateTime.now());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getPriorityColor(priority).withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.all(16),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(priority).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.campaign,
                            color: _getPriorityColor(priority),
                            size: 24,
                          ),
                        ),
                        title: Text(
                          title ?? 'Announcement',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              content.length > 60 ? '${content.substring(0, 60)}...' : content,
                              style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(priority).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    priority.toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: _getPriorityColor(priority),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (expiryDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isExpired
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isExpired
                                          ? 'EXPIRED'
                                          : 'Expires: ${DateFormat('MMM d').format(expiryDate.toDate())}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        color: isExpired ? Colors.red : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        children: [
                          Divider(color: Colors.grey[300]),
                          Text(
                            content,
                            style: GoogleFonts.montserrat(fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: audience.map((r) {
                              final label = r == 'all' ? 'Everyone' : r.capitalize();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: Text('Edit', style: GoogleFonts.montserrat(fontSize: 13)),
                                onPressed: () => _showEditDialog(
                                  docId: d.id,
                                  initialContent: content,
                                  initialAudience: audience,
                                  initialPriority: priority,
                                  initialExpiry: expiryDate?.toDate(),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue[700],
                                  side: BorderSide(color: Colors.blue[300]!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete, size: 18),
                                label: Text('Delete', style: GoogleFonts.montserrat(fontSize: 13)),
                                onPressed: () => _confirmDelete(d.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
