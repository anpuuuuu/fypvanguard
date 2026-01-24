// lib/user/emergency_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'RegisterVisitorForm.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({Key? key}) : super(key: key);

  @override
  _EmergencyPageState createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool _sending = false;
  String? _managementNumber;
  String? _securityNumber;
  String? _policeNumber;
  String? _fireNumber;
  bool _loadingNumbers = true;
  String _selectedEmergencyType = 'alert_guard';
  
  final List<Map<String, dynamic>> _emergencyTypes = [
    {'type': 'alert_guard', 'label': 'Alert Security', 'icon': Icons.security, 'color': Colors.red},
    {'type': 'fire', 'label': 'Fire Emergency', 'icon': Icons.local_fire_department, 'color': Colors.red},
    {'type': 'medical', 'label': 'Medical Emergency', 'icon': Icons.medical_services, 'color': Colors.red},
    {'type': 'break_in', 'label': 'Break-in/Suspicious', 'icon': Icons.warning, 'color': Colors.orange},
    {'type': 'flood', 'label': 'Flood/Water Leak', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'type': 'power_outage', 'label': 'Power Outage', 'icon': Icons.power_off, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('emergencyContacts').get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _managementNumber = data['managementOffice'];
          _securityNumber = data['security'];
          _policeNumber = data['police'];
          _fireNumber = data['fire'];
          _loadingNumbers = false;
        });
      } else {
        setState(() {
          _loadingNumbers = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingNumbers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load emergency contacts: $e')),
        );
      }
    }
  }

  Future<void> _sendEmergencyAlert(String type) async {
    setState(() => _sending = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // Get resident info
      final residentDoc = await FirebaseFirestore.instance
          .collection('residents')
          .doc(uid)
          .get();
      final residentData = residentDoc.data();
      
      await FirebaseFirestore.instance.collection('emergencies').add({
        'residentId': uid,
        'fullName': residentData?['fullName'] ?? 'Unknown',
        'unitNumber': residentData?['unitNumber'] ?? 'Unknown',
        'contactNumber': residentData?['contactNumber'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'status': 'pending',
        'priority': type == 'fire' || type == 'medical' ? 'urgent' : 'high',
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergency alert sent! Help is on the way.',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send alert: $e', style: GoogleFonts.montserrat()),
            backgroundColor: Colors.red.shade300,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showEntryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Entry Type', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.directions_walk),
              label: Text('Walk-In', style: GoogleFonts.montserrat()),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterVisitorForm(entryType: 'walk-in')),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.directions_car),
              label: Text('By Car', style: GoogleFonts.montserrat()),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterVisitorForm(entryType: 'car')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not dial $number', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.red.shade300,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency types section
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.red.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emergency, color: Colors.red.shade700, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Emergency Alerts',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the type of emergency and send an alert',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _emergencyTypes.length,
                    itemBuilder: (context, index) {
                      final emergency = _emergencyTypes[index];
                      final isSelected = _selectedEmergencyType == emergency['type'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedEmergencyType = emergency['type'];
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? emergency['color'].withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? emergency['color']
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                emergency['icon'],
                                size: 36,
                                color: emergency['color'],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                emergency['label'],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: _sending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, size: 24),
                      label: Text(
                        _sending ? 'Sending...' : 'Send Emergency Alert',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _sending
                          ? null
                          : () => _sendEmergencyAlert(_selectedEmergencyType),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Quick Call',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _EmergencyButton(
                    icon: Icons.call,
                    label: 'Call Management Office',
                    color: Colors.blue.shade700,
                    loading: _loadingNumbers,
                    onPressed: _managementNumber == null
                        ? null
                        : () => _callNumber(_managementNumber!),
                  ),
                  const SizedBox(height: 12),
                  _EmergencyButton(
                    icon: Icons.security,
                    label: 'Call Security',
                    color: Colors.blue.shade900,
                    loading: _loadingNumbers,
                    onPressed: _securityNumber == null
                        ? null
                        : () => _callNumber(_securityNumber!),
                  ),
                  if (_policeNumber != null && _policeNumber!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _EmergencyButton(
                      icon: Icons.local_police,
                      label: 'Call Police',
                      color: Colors.blue.shade800,
                      loading: false,
                      onPressed: () => _callNumber(_policeNumber!),
                    ),
                  ],
                  if (_fireNumber != null && _fireNumber!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _EmergencyButton(
                      icon: Icons.local_fire_department,
                      label: 'Call Fire Department',
                      color: Colors.red,
                      loading: false,
                      onPressed: () => _callNumber(_fireNumber!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
              GoRouter.of(context).go('/user');
              break;
            case 1:
              _showEntryDialog();
              break;
            case 2:
              GoRouter.of(context).go('/user/bookFacility');
              break;
            case 3:
              GoRouter.of(context).go('/user/maintenanceRequest');
              break;
            case 4:
              GoRouter.of(context).go('/userprofile');
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

class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _EmergencyButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: loading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
            : Icon(icon, size: 24),
        label: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: Colors.white, // changed to white for readability
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: loading ? null : onPressed,
      ),
    );
  }
}
