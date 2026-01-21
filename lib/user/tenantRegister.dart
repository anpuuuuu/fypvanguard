// lib/user/tenant_register.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class TenantRegisterPage extends StatefulWidget {
  const TenantRegisterPage({Key? key}) : super(key: key);

  @override
  _TenantRegisterPageState createState() => _TenantRegisterPageState();
}

class _TenantRegisterPageState extends State<TenantRegisterPage> {
  final _emailCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _unitCtrl    = TextEditingController();
  bool _isLoading    = false;
  String? _contactError;

  @override
  void initState() {
    super.initState();
    _loadOwnerUnit();
  }

  Future<void> _loadOwnerUnit() async {
    final owner = FirebaseAuth.instance.currentUser;
    if (owner == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('residents')
        .doc(owner.uid)
        .get();
    final unit = snap.data()?['unitNumber'] as String? ?? '';
    _unitCtrl.text = unit;
  }

  Future<void> _registerTenant() async {
    final email   = _emailCtrl.text.trim();
    final name    = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    final unit    = _unitCtrl.text.trim();

    if ([email, name, contact, unit].any((s) => s.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final phoneRe = RegExp(r'^\d{7,15}$');
    if (!phoneRe.hasMatch(contact)) {
      setState(() => _contactError = 'Enter 7–15 digits only');
      return;
    } else {
      setState(() => _contactError = null);
    }

    setState(() => _isLoading = true);
    try {
      // 1️⃣ Initialize a second FirebaseApp
      final secondaryApp = await Firebase.initializeApp(
        name: 'Secondary',
        options: Firebase.app().options,
      );

      // 2️⃣ Get its own Auth instance
      final secAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // 3️⃣ Create the tenant user under secondaryAuth (does NOT sign in primary)
      final cred = await secAuth.createUserWithEmailAndPassword(
        email: email,
        password: contact,
      );
      final tenantId = cred.user!.uid;

      // 4️⃣ Write tenant profile (using default Firestore)
      await FirebaseFirestore.instance
          .collection('residents')
          .doc(tenantId)
          .set({
        'fullName': name,
        'contactNumber': contact,
        'unitNumber': unit,
        'ownerId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(tenantId)
          .set({
        'username': email,
        'role': 'tenant',
        'status': 'approved',
        'residentId': tenantId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5️⃣ Clean up secondaryAuth & secondaryApp
      await secAuth.signOut();
      await secondaryApp.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant registered successfully')),
      );
      GoRouter.of(context).go('/mytenant');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade700),
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
        centerTitle: true,
        title: Text('Register Tenant',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/mytenant'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email
                  TextField(
                    controller: _emailCtrl,
                    decoration: _inputDecoration('Tenant Email'),
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.montserrat(),
                  ),
                  const SizedBox(height: 16),

                  // Full Name
                  TextField(
                    controller: _nameCtrl,
                    decoration: _inputDecoration('Full Name'),
                    style: GoogleFonts.montserrat(),
                  ),
                  const SizedBox(height: 16),

                  // Contact (password)
                  TextField(
                    controller: _contactCtrl,
                    decoration: _inputDecoration(
                      'Contact Number (used as password)',
                    ).copyWith(
                      errorText: _contactError,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: GoogleFonts.montserrat(),
                  ),
                  const SizedBox(height: 16),

                  // Unit (read‐only)
                  TextField(
                    controller: _unitCtrl,
                    decoration: _inputDecoration('Unit Number'),
                    readOnly: true,
                    style: GoogleFonts.montserrat(),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed:
                      _isLoading ? null : () => _registerTenant(),
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : Text('Register Tenant',
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
