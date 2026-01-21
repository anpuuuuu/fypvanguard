// lib/security/emergency_alerts.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class EmergencyAlertsPage extends StatefulWidget {
  const EmergencyAlertsPage({Key? key}) : super(key: key);

  @override
  _EmergencyAlertsPageState createState() => _EmergencyAlertsPageState();
}

class _EmergencyAlertsPageState extends State<EmergencyAlertsPage> {
  final _firestore = FirebaseFirestore.instance;

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
        Text('Name: ${residentInfo['fullName']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        Text('Unit: ${residentInfo['unitNumber']}', style: GoogleFonts.montserrat()),
        Text('Contact: ${residentInfo['contactNumber']}', style: GoogleFonts.montserrat()),
      ],
    );
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('emergencies')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.montserrat(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No emergency alerts.', style: GoogleFonts.montserrat(color: Colors.grey)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;
              final residentId = data['residentId'] as String?;
              final type = data['type'] as String? ?? 'unknown';
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              final timeStr = ts == null
                  ? 'Unknown time'
                  : '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

              return FutureBuilder<Map<String, dynamic>>(
                future: residentId == null ? Future.value({}) : _fetchResidentInfo(residentId),
                builder: (context, resSnap) {
                  if (resSnap.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      title: Text('Loading resident info...', style: GoogleFonts.montserrat()),
                      subtitle: Text(timeStr, style: GoogleFonts.montserrat(fontSize: 12)),
                    );
                  }

                  final residentInfo = resSnap.data ?? {};
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: ListTile(
                      leading: Icon(Icons.notification_important, color: Colors.red.shade700),
                      title: Text(
                        'Emergency Alert: ${type.replaceAll('_', ' ').toUpperCase()}',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(timeStr, style: GoogleFonts.montserrat(fontSize: 12)),
                          const SizedBox(height: 6),
                          _buildResidentInfo(residentInfo),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Optional: Show detailed dialog or navigate for more info
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Emergency Details', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Type: ${type.replaceAll('_', ' ').toUpperCase()}', style: GoogleFonts.montserrat()),
                                const SizedBox(height: 8),
                                Text('Time: $timeStr', style: GoogleFonts.montserrat()),
                                const SizedBox(height: 12),
                                _buildResidentInfo(residentInfo),
                              ],
                            ),
                            actions: [
                              TextButton(
                                child: Text('Close', style: GoogleFonts.montserrat()),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
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
}
