// lib/admin/maintenance_management.dart
// Admin maintenance management page

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/maintenance_service.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({Key? key}) : super(key: key);

  @override
  State<MaintenanceManagementPage> createState() => _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  final _service = MaintenanceService();
  String _selectedFilter = 'All';
  String _selectedPriority = 'All';
  String _searchQuery = '';
  
  final List<String> _statusFilters = ['All', 'created', 'in_progress', 'resolved'];
  final List<String> _priorityFilters = ['All', 'urgent', 'high', 'medium', 'low'];

  Future<Map<String, String>> _getResidentInfo(String residentId) async {
    try {
      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(residentId)
          .get();
      
      final accountData = accountDoc.data();
      final residentIdFromAccount = accountData?['residentId'] as String? ?? residentId;
      
      final residentDoc = await FirebaseFirestore.instance
          .collection('residents')
          .doc(residentIdFromAccount)
          .get();
      
      final residentData = residentDoc.data();
      return {
        'name': residentData?['fullName'] as String? ?? 'Unknown User',
        'unit': residentData?['unitNumber'] as String? ?? 'N/A',
        'email': accountData?['email'] as String? ?? 'No email',
      };
    } catch (e) {
      return {
        'name': 'Unknown User',
        'unit': 'N/A',
        'email': 'No email',
      };
    }
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

  void _viewRequestDetails(Map<String, dynamic> data, String requestId) async {
    final residentInfo = await _getResidentInfo(data['residentId'] as String? ?? '');
    final comments = data['comments'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Maintenance Request Details',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Request ID', requestId),
              _buildDetailRow('Resident', '${residentInfo['name']} (Unit ${residentInfo['unit']})'),
              _buildDetailRow('Email', residentInfo['email']!),
              const Divider(),
              _buildDetailRow('Description', data['description'] as String? ?? 'N/A'),
              if (data['location'] != null)
                _buildDetailRow('Location', data['location'] as String),
              _buildDetailRow('Category', _getCategoryLabel(data['category'] as String? ?? 'general')),
              _buildDetailRow('Priority', _getPriorityLabel(data['priority'] as String? ?? 'medium')),
              _buildDetailRow('Status', (data['status'] as String? ?? 'created').toUpperCase()),
              if (data['assignedTo'] != null)
                _buildDetailRow('Assigned To', data['assignedTo'] as String),
              if (data['estimatedCost'] != null)
                _buildDetailRow('Estimated Cost', 'RM ${(data['estimatedCost'] as num).toStringAsFixed(2)}'),
              if (data['actualCost'] != null)
                _buildDetailRow('Actual Cost', 'RM ${(data['actualCost'] as num).toStringAsFixed(2)}'),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  'Created At',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(
                    (data['createdAt'] as Timestamp).toDate(),
                  ),
                ),
              if (data['completedAt'] != null)
                _buildDetailRow(
                  'Completed At',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(
                    (data['completedAt'] as Timestamp).toDate(),
                  ),
                ),
              if (comments.isNotEmpty) ...[
                const Divider(),
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
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commentData['userName'] as String? ?? 'Unknown',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          commentData['comment'] as String? ?? '',
                          style: GoogleFonts.montserrat(fontSize: 12),
                        ),
                        if (commentData['createdAt'] != null)
                          Text(
                            DateFormat('MMM dd, yyyy HH:mm').format(
                              (commentData['createdAt'] as Timestamp).toDate(),
                            ),
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              if (data['imageBase64'] != null) ...[
                const Divider(),
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
            child: Text('Close', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Text(
          'Maintenance Management',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by description...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                // Status Filter
                Row(
                  children: [
                    Text(
                      'Status:',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        items: _statusFilters.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status == 'All' ? status : status.toUpperCase(),
                              style: GoogleFonts.montserrat(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedFilter = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Priority:',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedPriority,
                        isExpanded: true,
                        items: _priorityFilters.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Text(
                              priority == 'All' ? priority : _getPriorityLabel(priority),
                              style: GoogleFonts.montserrat(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPriority = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Requests List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.streamAllRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.montserrat(),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Filter by status, priority, and search
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'created';
                  final priority = data['priority'] as String? ?? 'medium';
                  final description = (data['description'] as String? ?? '').toLowerCase();
                  
                  bool statusMatch = _selectedFilter == 'All' || status == _selectedFilter;
                  bool priorityMatch = _selectedPriority == 'All' || priority == _selectedPriority;
                  bool searchMatch = _searchQuery.isEmpty || description.contains(_searchQuery);
                  
                  return statusMatch && priorityMatch && searchMatch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No Maintenance Requests',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final requestId = doc.id;
                    final status = data['status'] as String? ?? 'created';
                    final priority = data['priority'] as String? ?? 'medium';
                    final category = data['category'] as String? ?? 'general';
                    final description = data['description'] as String? ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    
                    return FutureBuilder<Map<String, String>>(
                      future: _getResidentInfo(data['residentId'] as String? ?? ''),
                      builder: (context, residentSnapshot) {
                        final residentInfo = residentSnapshot.data ?? {
                          'name': 'Loading...',
                          'unit': 'N/A',
                        };
                        
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _viewRequestDetails(data, requestId),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              residentInfo['name']!,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'Unit ${residentInfo['unit']}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: _getStatusColor(status),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: GoogleFonts.montserrat(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getPriorityColor(priority).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: _getPriorityColor(priority),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _getPriorityLabel(priority),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: _getPriorityColor(priority),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _getCategoryLabel(category),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (createdAt != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate()),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
    );
  }
}
