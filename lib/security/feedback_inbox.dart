// lib/security/feedback_inbox.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FeedbackInboxPage extends StatefulWidget {
  const FeedbackInboxPage({Key? key}) : super(key: key);

  @override
  State<FeedbackInboxPage> createState() => _FeedbackInboxPageState();
}

class _FeedbackInboxPageState extends State<FeedbackInboxPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, pending, in_progress, resolved
  String _filterPriority = 'All'; // All, Low, Medium, High, Urgent

  @override
  void dispose() {
    _searchController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _markRead(String id) =>
      FirebaseFirestore.instance.collection('feedback').doc(id).update({'readBy': true});

  Future<void> _updateStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('feedback').doc(id).update({
      'status': status,
      'readBy': true,
    });
  }

  void _showResponseDialog(String feedbackId, String currentResponse) {
    _responseController.text = currentResponse;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Response', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: _responseController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter your response...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_responseController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('feedback').doc(feedbackId).update({
                  'response': _responseController.text.trim(),
                  'status': 'resolved',
                  'readBy': true,
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Response added', style: GoogleFonts.montserrat()),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Send', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'Urgent': return Colors.red;
      case 'High': return Colors.orange;
      case 'Medium': return Colors.blue;
      case 'Low': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        title: Text('Feedback Inbox', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(ctx).go('/security'),
        ),
      ),
      body: Column(
        children: [
          // Search and filters
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
                    hintText: 'Search feedback...',
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: ['All', 'pending', 'in_progress', 'resolved'].map((status) {
                              return FilterChip(
                                label: Text(status == 'All' ? 'All' : status.replaceAll('_', ' ').toUpperCase(),
                                    style: GoogleFonts.montserrat(fontSize: 11)),
                                selected: _filterStatus == status,
                                onSelected: (_) => setState(() => _filterStatus = status),
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Priority', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: ['All', 'Low', 'Medium', 'High', 'Urgent'].map((priority) {
                              return FilterChip(
                                label: Text(priority, style: GoogleFonts.montserrat(fontSize: 11)),
                                selected: _filterPriority == priority,
                                onSelected: (_) => setState(() => _filterPriority = priority),
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Statistics
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('feedback').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              final pending = docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
              final inProgress = docs.where((d) => (d.data() as Map)['status'] == 'in_progress').length;
              final resolved = docs.where((d) => (d.data() as Map)['status'] == 'resolved').length;
              
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Pending', pending, Colors.orange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('In Progress', inProgress, Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('Resolved', resolved, Colors.green),
                    ),
                  ],
                ),
              );
            },
          ),
          // Feedback list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('feedback')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${snap.error}', style: GoogleFonts.montserrat(color: Colors.red)),
                      ],
                    ),
                  );
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                
                // Filter
                final filteredDocs = docs.where((doc) {
                  final d = doc.data()! as Map<String, dynamic>;
                  final message = (d['message'] ?? '').toString().toLowerCase();
                  final fullName = (d['fullName'] ?? '').toString().toLowerCase();
                  final status = d['status'] as String? ?? 'pending';
                  final priority = d['priority'] as String? ?? 'Medium';
                  
                  bool matchesSearch = _searchQuery.isEmpty ||
                      message.contains(_searchQuery) ||
                      fullName.contains(_searchQuery);
                  
                  bool matchesStatus = _filterStatus == 'All' || status == _filterStatus;
                  bool matchesPriority = _filterPriority == 'All' || priority == _filterPriority;
                  
                  return matchesSearch && matchesStatus && matchesPriority;
                }).toList();
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No feedback found',
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
                  itemBuilder: (_, i) {
                    final d = filteredDocs[i].data()! as Map<String, dynamic>;
                    final read = d['readBy'] as bool? ?? false;
                    final status = d['status'] as String? ?? 'pending';
                    final priority = d['priority'] as String? ?? 'Medium';
                    final category = d['category'] as String? ?? 'General';
                    final unitNumber = d['unitNumber'] as String? ?? 'N/A';
                    final ts = (d['createdAt'] as Timestamp?)?.toDate().toLocal();
                    final time = ts == null ? '' : DateFormat('MMM d, yyyy h:mm a').format(ts);
                    final response = d['response'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: read ? Colors.grey[200]! : Colors.orange[200]!,
                          width: read ? 1 : 2,
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
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(priority).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.feedback,
                            color: _getPriorityColor(priority),
                            size: 24,
                          ),
                        ),
                        title: Text(
                          d['fullName'] ?? 'Guest',
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
                              d['message'] ?? '',
                              style: GoogleFonts.montserrat(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    category,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(priority).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    priority,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: _getPriorityColor(priority),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Unit $unitNumber • $time',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: read
                            ? Icon(Icons.check_circle, color: Colors.green[600], size: 20)
                            : Icon(Icons.mark_email_unread, color: Colors.orange[600], size: 20),
                        children: [
                          Divider(color: Colors.grey[300]),
                          if (response != null) ...[
                            Text(
                              'Response:',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                response,
                                style: GoogleFonts.montserrat(fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              if (status != 'resolved')
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.reply, size: 16),
                                    label: Text('Respond', style: GoogleFonts.montserrat(fontSize: 12)),
                                    onPressed: () => _showResponseDialog(filteredDocs[i].id, response ?? ''),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue[700],
                                      side: BorderSide(color: Colors.blue[300]!),
                                    ),
                                  ),
                                ),
                              if (status != 'resolved') const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(
                                    status == 'resolved' ? 'Resolved' : 'Mark Resolved',
                                    style: GoogleFonts.montserrat(fontSize: 12),
                                  ),
                                  onPressed: status == 'resolved'
                                      ? null
                                      : () => _updateStatus(filteredDocs[i].id, 'resolved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    disabledBackgroundColor: Colors.grey[300],
                                  ),
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

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
