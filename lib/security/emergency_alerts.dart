// lib/security/emergency_alerts.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyAlertsPage extends StatefulWidget {
  const EmergencyAlertsPage({Key? key}) : super(key: key);

  @override
  _EmergencyAlertsPageState createState() => _EmergencyAlertsPageState();
}

class _EmergencyAlertsPageState extends State<EmergencyAlertsPage> {
  final _firestore = FirebaseFirestore.instance;
  String _filterStatus = 'All'; // All, pending, responding, resolved
  String _filterPriority = 'All'; // All, high, urgent

  Future<Map<String, dynamic>> _fetchResidentInfo(String residentId) async {
    final doc = await _firestore.collection('residents').doc(residentId).get();
    if (!doc.exists) return {};
    final data = doc.data()!;
    return {
      'fullName': data['fullName'] ?? 'Unknown',
      'unitNumber': data['unitNumber'] ?? 'Unknown',
      'contactNumber': data['contactNumber'] ?? 'Unknown',
    };
  }

  Widget _buildResidentInfo(Map<String, dynamic> residentInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text('${residentInfo['fullName']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.home, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text('Unit ${residentInfo['unitNumber']}', style: GoogleFonts.montserrat()),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.phone, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text('${residentInfo['contactNumber']}', style: GoogleFonts.montserrat()),
          ],
        ),
      ],
    );
  }

  Future<void> _updateEmergencyStatus(String docId, String status) async {
    await _firestore.collection('emergencies').doc(docId).update({
      'status': status,
      'respondedAt': status == 'resolved' ? FieldValue.serverTimestamp() : null,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${status.replaceAll('_', ' ')}', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _callResident(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $number', style: GoogleFonts.montserrat())),
        );
      }
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'resolved': return Colors.green;
      case 'responding': return Colors.blue;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Alerts', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: ['All', 'pending', 'responding', 'resolved'].map((status) {
                          return FilterChip(
                            label: Text(status == 'All' ? 'All' : status.toUpperCase(),
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
                        children: ['All', 'high', 'urgent'].map((priority) {
                          return FilterChip(
                            label: Text(priority.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 11)),
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
          ),
          // Emergency alerts list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('emergencies')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}', style: GoogleFonts.montserrat(color: Colors.red)),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                
                // Filter
                final filteredDocs = docs.where((doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'pending';
                  final priority = data['priority'] as String? ?? 'high';
                  
                  bool matchesStatus = _filterStatus == 'All' || status == _filterStatus;
                  bool matchesPriority = _filterPriority == 'All' || priority == _filterPriority;
                  
                  return matchesStatus && matchesPriority;
                }).toList();
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No emergency alerts',
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
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data()! as Map<String, dynamic>;
                    final residentId = data['residentId'] as String?;
                    final type = data['type'] as String? ?? 'unknown';
                    final status = data['status'] as String? ?? 'pending';
                    final priority = data['priority'] as String? ?? 'high';
                    final ts = (data['timestamp'] as Timestamp?)?.toDate().toLocal();
                    final timeStr = ts == null
                        ? 'Unknown time'
                        : DateFormat('MMM d, yyyy h:mm a').format(ts);
                    final relativeTime = ts == null
                        ? ''
                        : _getRelativeTime(ts);

                    return FutureBuilder<Map<String, dynamic>>(
                      future: residentId == null ? Future.value({}) : _fetchResidentInfo(residentId),
                      builder: (context, resSnap) {
                        if (resSnap.connectionState == ConnectionState.waiting) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(width: 16),
                                Text('Loading...', style: GoogleFonts.montserrat()),
                              ],
                            ),
                          );
                        }

                        final residentInfo = resSnap.data ?? {};
                        final contactNumber = residentInfo['contactNumber'] as String? ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getPriorityColor(priority),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.all(16),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(priority).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getEmergencyIcon(type),
                                color: _getPriorityColor(priority),
                                size: 28,
                              ),
                            ),
                            title: Text(
                              type.replaceAll('_', ' ').toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _getPriorityColor(priority),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
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
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(priority).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        priority.toUpperCase(),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: _getPriorityColor(priority),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  relativeTime,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[600],
                            ),
                            children: [
                              Divider(color: Colors.grey[300]),
                              _buildResidentInfo(residentInfo),
                              const SizedBox(height: 16),
                              if (status != 'resolved')
                                Row(
                                  children: [
                                    if (contactNumber.isNotEmpty)
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.phone, size: 18),
                                          label: Text('Call', style: GoogleFonts.montserrat(fontSize: 13)),
                                          onPressed: () => _callResident(contactNumber),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue[700],
                                            side: BorderSide(color: Colors.blue[300]!),
                                          ),
                                        ),
                                      ),
                                    if (contactNumber.isNotEmpty) const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle, size: 18),
                                        label: Text(
                                          status == 'responding' ? 'Resolve' : 'Respond',
                                          style: GoogleFonts.montserrat(fontSize: 13),
                                        ),
                                        onPressed: () {
                                          final newStatus = status == 'responding' ? 'resolved' : 'responding';
                                          _updateEmergencyStatus(doc.id, newStatus);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: status == 'responding'
                                              ? Colors.green[600]
                                              : Colors.blue[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (status == 'resolved')
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Resolved',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
      bottomNavigationBar: BottomNavigationBar(
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

  IconData _getEmergencyIcon(String type) {
    switch (type) {
      case 'fire': return Icons.local_fire_department;
      case 'medical': return Icons.medical_services;
      case 'break_in': return Icons.warning;
      case 'flood': return Icons.water_drop;
      case 'power_outage': return Icons.power_off;
      default: return Icons.emergency;
    }
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
