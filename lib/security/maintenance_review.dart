// lib/security/maintenance_review.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/services/maintenance_service.dart';

class MaintenanceReviewPage extends StatefulWidget {
  const MaintenanceReviewPage({Key? key}) : super(key: key);

  @override
  _MaintenanceReviewPageState createState() => _MaintenanceReviewPageState();
}

class _MaintenanceReviewPageState extends State<MaintenanceReviewPage> {
  final _service = MaintenanceService();
  String _search = '';
  String _filterStatus = 'All'; // All, created, in_progress, resolved
  String _filterPriority = 'All'; // All, urgent, high, medium, low
  String _sortBy = 'newest'; // newest, oldest, priority

  Future<Map<String, String>> _fetchResident(String rid) async {
    final doc = await FirebaseFirestore.instance
        .collection('residents')
        .doc(rid)
        .get();
    if (!doc.exists) return {'fullName': 'Unknown', 'unit': 'Unknown'};
    final d = doc.data()!;
    return {
      'fullName': d['fullName'] as String? ?? 'Unknown',
      'unit': d['unitNumber'] as String? ?? 'Unknown',
    };
  }

  String _relativeTime(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'urgent': return 'Urgent';
      case 'high': return 'High';
      case 'medium': return 'Medium';
      case 'low': return 'Low';
      default: return priority;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'plumbing': return 'Plumbing';
      case 'electrical': return 'Electrical';
      case 'hvac': return 'HVAC';
      case 'structural': return 'Structural';
      case 'general': return 'General';
      case 'other': return 'Other';
      default: return category;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.blue;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'resolved': return Colors.green;
      case 'in_progress': return Colors.orange;
      case 'created': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _statusAllowed(String s) {
    if (_filterStatus == 'All') return true;
    return s == _filterStatus;
  }

  void _showCommentDialog(String requestId, String userId, String userName) {
    final commentController = TextEditingController();
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Add Comment/Update',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(
              hintText: 'Enter your comment or update...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 4,
            style: GoogleFonts.montserrat(),
            enabled: !isSubmitting,
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.montserrat()),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                final commentText = commentController.text.trim();
                if (commentText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a comment')),
                  );
                  return;
                }
                
                setDialogState(() => isSubmitting = true);
                
                try {
                  await _service.addComment(
                    requestId: requestId,
                    userId: userId,
                    userName: userName,
                    comment: commentText,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Comment added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add comment: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Add', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> data, String requestId) async {
    final residentInfo = await _fetchResident(data['residentId'] as String? ?? '');
    final comments = data['comments'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Request Details',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Resident', '${residentInfo['fullName']} (Unit ${residentInfo['unit']})'),
              _buildDetailRow('Description', data['description'] as String? ?? 'N/A'),
              if (data['location'] != null && (data['location'] as String).isNotEmpty)
                _buildDetailRow('Location', data['location'] as String),
              _buildDetailRow('Category', _getCategoryLabel(data['category'] as String? ?? 'general')),
              _buildDetailRow('Priority', _getPriorityLabel(data['priority'] as String? ?? 'medium')),
              _buildDetailRow('Status', data['status'] == 'created' ? 'Created' : data['status'] == 'in_progress' ? 'In Progress' : 'Resolved'),
              if (data['assignedTo'] != null)
                _buildDetailRow('Assigned To', data['assignedTo'] as String),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  'Created',
                  DateFormat('MMM dd, yyyy HH:mm').format(
                    (data['createdAt'] as Timestamp).toDate(),
                  ),
                ),
              if (data['completedAt'] != null)
                _buildDetailRow(
                  'Completed',
                  DateFormat('MMM dd, yyyy HH:mm').format(
                    (data['completedAt'] as Timestamp).toDate(),
                  ),
                ),
              if (comments.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Comments/Updates:',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...comments.map((comment) {
                  final commentData = comment as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              commentData['userName'] as String? ?? 'Unknown',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                              ),
                            ),
                            if (commentData['createdAt'] != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '·',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, HH:mm').format(
                                  (commentData['createdAt'] as Timestamp).toDate(),
                                ),
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          commentData['comment'] as String? ?? '',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              if (data['imageBase64'] != null) ...[
                const Divider(height: 24),
                Text(
                  'Image:',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        insetPadding: EdgeInsets.zero,
                        backgroundColor: Colors.black,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: InteractiveViewer(
                            child: Image.memory(
                              base64Decode(data['imageBase64'] as String),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.memory(
                    base64Decode(data['imageBase64'] as String),
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[900],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }



  int _getPriorityOrder(String priority) {
    switch (priority) {
      case 'urgent': return 0;
      case 'high': return 1;
      case 'medium': return 2;
      case 'low': return 3;
      default: return 4;
    }
  }

  List<DocumentSnapshot> _sortRequests(List<DocumentSnapshot> docs) {
    final sorted = List<DocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      if (_sortBy == 'priority') {
        final aPriority = aData['priority'] as String? ?? 'medium';
        final bPriority = bData['priority'] as String? ?? 'medium';
        return _getPriorityOrder(aPriority).compareTo(_getPriorityOrder(bPriority));
      } else if (_sortBy == 'oldest') {
        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      } else { // newest
        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      }
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ['All', 'created', 'in_progress', 'resolved'];
    final priorities = ['All', 'urgent', 'high', 'medium', 'low'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Review Maintenance',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Maintenance Review',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                  content: Text(
                    'Review and manage maintenance requests. You can:\n\n'
                    '• View request details\n'
                    '• Add comments/updates\n'
                    '• Update request status\n'
                    '• Filter by status and priority\n'
                    '• Search requests',
                    style: GoogleFonts.montserrat(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK', style: GoogleFonts.montserrat()),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: Column(
          children: [
            // Statistics Cards
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('maintenanceRequests')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                
                final docs = snapshot.data!.docs;
                final created = docs.where((d) => (d.data() as Map)['status'] == 'created').length;
                final inProgress = docs.where((d) => (d.data() as Map)['status'] == 'in_progress').length;
                final resolved = docs.where((d) => (d.data() as Map)['status'] == 'resolved').length;
                
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Pending', created, Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('In Progress', inProgress, Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Resolved', resolved, Colors.green),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Filters Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by description, location, or resident...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  ),
                  const SizedBox(height: 16),
                  // Status and Priority Filters
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: statuses.map((st) {
                                return FilterChip(
                                  label: Text(
                                    st == 'All' ? 'All' : st == 'created' ? 'Created' : st == 'in_progress' ? 'In Progress' : 'Resolved',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  selected: _filterStatus == st,
                                  onSelected: (_) => setState(() => _filterStatus = st),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  selectedColor: Colors.red.shade50,
                                  checkmarkColor: Colors.red.shade700,
                                  labelStyle: TextStyle(
                                    color: _filterStatus == st ? Colors.red.shade700 : Colors.grey[700],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Priority',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: priorities.map((p) {
                                return FilterChip(
                                  label: Text(
                                    p == 'All' ? 'All' : _getPriorityLabel(p),
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  selected: _filterPriority == p,
                                  onSelected: (_) => setState(() => _filterPriority = p),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  selectedColor: Colors.red.shade50,
                                  checkmarkColor: Colors.red.shade700,
                                  labelStyle: TextStyle(
                                    color: _filterPriority == p ? Colors.red.shade700 : Colors.grey[700],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Sort Options
                  Row(
                    children: [
                      Text(
                        'Sort',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'newest', label: Text('Newest')),
                            ButtonSegment(value: 'oldest', label: Text('Oldest')),
                            ButtonSegment(value: 'priority', label: Text('Priority')),
                          ],
                          selected: {_sortBy},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() => _sortBy = newSelection.first);
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: Colors.red.shade700,
                            selectedForegroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stream of maintenance requests
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('maintenanceRequests')
                    .snapshots(),
                builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                      child: Text('Error: ${snap.error}',
                          style: GoogleFonts.montserrat()));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;

                // client-side search + filter
                // First filter by status and priority (no async needed)
                final preFiltered = docs.where((doc) {
                  final d = doc.data()! as Map<String, dynamic>;
                  final status = (d['status'] as String? ?? '');
                  final priority = (d['priority'] as String? ?? 'medium');
                  
                  // Status filter
                  bool statusMatch = _filterStatus == 'All' || status == _filterStatus;
                  
                  // Priority filter
                  bool priorityMatch = _filterPriority == 'All' || priority == _filterPriority;
                  
                  return statusMatch && priorityMatch;
                }).toList();
                
                // Then filter by search (description, location)
                final list = preFiltered.where((doc) {
                  if (_search.isEmpty) return true;
                  
                  final d = doc.data()! as Map<String, dynamic>;
                  final desc = (d['description'] as String? ?? '').toLowerCase();
                  final location = (d['location'] as String? ?? '').toLowerCase();
                  
                  return desc.contains(_search) || location.contains(_search);
                }).toList();
                
                // Sort the filtered list
                final sortedList = _sortRequests(list);

                if (sortedList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 20),
                        Text(
                          'No Matching Requests',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: sortedList.length,
                  itemBuilder: (ctx, i) {
                    final doc = sortedList[i];
                    final d = doc.data()! as Map<String, dynamic>;
                    final mid = doc.id;
                    final ts = d['createdAt'] as Timestamp?;
                    final rel = _relativeTime(ts);
                    final base64 = d['imageBase64'] as String?;
                    final status = d['status'] as String? ?? 'created';

                    // Get current user info for comments
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final currentUserName = 'Security Staff'; // Could be fetched from user profile
                    
                    // choose button
                    Widget action;
                    if (status == 'created') {
                      action = Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.comment_outlined, size: 16),
                              label: Text('Add Comment',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue[300]!, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _showCommentDialog(mid, currentUser?.uid ?? '', currentUserName),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: Text('In Progress',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                              onPressed: () async {
                                final currentUser = FirebaseAuth.instance.currentUser;
                                await _service.updateRequestStatus(
                                  requestId: mid,
                                  status: 'in_progress',
                                  userId: currentUser?.uid ?? '',
                                  userName: 'Security Staff',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Marked In Progress')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    } else if (status == 'in_progress') {
                      action = Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.update, size: 16),
                              label: Text('Update',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue[300]!, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _showCommentDialog(mid, currentUser?.uid ?? '', currentUserName),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: Text('Resolve',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                              onPressed: () async {
                                final currentUser = FirebaseAuth.instance.currentUser;
                                await _service.updateRequestStatus(
                                  requestId: mid,
                                  status: 'resolved',
                                  userId: currentUser?.uid ?? '',
                                  userName: 'Security Staff',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Marked Resolved')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    } else {
                      action = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.green[700], size: 18),
                            const SizedBox(width: 6),
                            Text('Resolved',
                                style: GoogleFonts.montserrat(
                                  color: Colors.green[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                      );
                    }

                    return FutureBuilder<Map<String, String>>(
                      future: _fetchResident(d['residentId'] as String? ?? ''),
                      builder: (ctx2, fb) {
                        final res = fb.data ?? {'fullName': '…', 'unit': '…'};
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 16),
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => _showRequestDetails(d, mid),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Name, Status, Time
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${res['fullName']} (Unit ${res['unit']})',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[900],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  rel,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getStatusColor(status).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          status == 'created' ? 'Created' : status == 'in_progress' ? 'In Progress' : 'Resolved',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: _getStatusColor(status),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Description
                                  Text(
                                    d['description'] as String? ?? '–',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  // Priority and Category badges
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (d['priority'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(d['priority'] as String).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _getPriorityColor(d['priority'] as String).withOpacity(0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.flag,
                                                size: 12,
                                                color: _getPriorityColor(d['priority'] as String),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _getPriorityLabel(d['priority'] as String),
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: _getPriorityColor(d['priority'] as String),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (d['category'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.blue.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.category, size: 12, color: Colors.blue[700]),
                                              const SizedBox(width: 4),
                                              Text(
                                                _getCategoryLabel(d['category'] as String),
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: Colors.blue[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (d['location'] != null && (d['location'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              d['location'] as String,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (base64 != null) ...[
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            insetPadding: EdgeInsets.zero,
                                            backgroundColor: Colors.black,
                                            child: GestureDetector(
                                              onTap: () => Navigator.pop(context),
                                              child: InteractiveViewer(
                                                child: Image.memory(
                                                  base64Decode(base64),
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          base64Decode(base64),
                                          height: 140,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ],
                                  // Comments count
                                  if (d['comments'] != null && (d['comments'] as List).isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.comment_outlined, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${(d['comments'] as List).length} comment${(d['comments'] as List).length > 1 ? 's' : ''}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Action buttons
                                  action,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4, // “Maintenance Review” is index 4
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/security');
              break;
            case 1:
              GoRouter.of(context).go('/security/visitorApproval');
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
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner), label: 'Approve'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_pin), label: 'Tracking'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_available), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Review'),
        ],
      ),
    );
  }
}
