// lib/user/emergency_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _loadingNumbers = true;

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
          _loadingNumbers = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingNumbers = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load emergency contacts: $e')),
      );
    }
  }

  Future<void> _alertGuardAndFamily() async {
    setState(() => _sending = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await FirebaseFirestore.instance.collection('emergencies').add({
        'residentId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'alert_guard',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert sent!', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.green.shade400,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send alert: $e', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.red.shade300,
        ),
      );
    } finally {
      setState(() => _sending = false);
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _EmergencyButton(
              icon: Icons.notifications_active,
              label: 'Alert Guard',
              color: Colors.red.shade700,
              loading: _sending,
              onPressed: _sending ? null : _alertGuardAndFamily,
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
            const SizedBox(height: 16),
            _EmergencyButton(
              icon: Icons.security,
              label: 'Call Security',
              color: Colors.blue.shade900,
              loading: _loadingNumbers,
              onPressed: _securityNumber == null
                  ? null
                  : () => _callNumber(_securityNumber!),
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
