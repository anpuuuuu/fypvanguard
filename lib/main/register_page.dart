// lib/main/register_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class OwnerRegisterScreen extends StatefulWidget {
  const OwnerRegisterScreen({Key? key}) : super(key: key);

  @override
  State<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends State<OwnerRegisterScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl= TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _unitCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController();

  File? _proofFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _unitCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (file != null) setState(() => _proofFile = File(file.path));
  }

  Future<void> _registerOwner() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final unit    = _unitCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    if ([name, email, pass, confirm, unit, contact].any((s) => s.isEmpty)) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (pass != confirm) {
      _showSnack('Passwords do not match');
      return;
    }
    if (_proofFile == null) {
      _showSnack('Please select proof document');
      return;
    }

    if (!RegExp(r'^\d{7,15}$').hasMatch(contact)) {
      _showSnack('Please enter a valid phone number (7–15 digits)');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: pass);
      final uid = cred.user!.uid;

      final bytes = await _proofFile!.readAsBytes();
      final base64Img = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('accounts').doc(uid).set({
        'username': email,
        'role': 'owner',
        'residentId': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('residents').doc(uid).set({
        'fullName': name,
        'unitNumber': unit,
        'contactNumber': contact,
        'proofDocBase64': base64Img,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();
      _showSnack('Registration successful');
      context.go('/login');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Registration failed');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Text(
          'Register Owner',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Full Name
              _buildField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person),
              const SizedBox(height: 16),

              // Email
              _buildField(controller: _emailCtrl, label: 'Email', icon: Icons.email, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 16),

              // Password
              _buildField(controller: _passwordCtrl, label: 'Password', icon: Icons.lock, obscure: true),
              const SizedBox(height: 16),

              // Confirm Password
              _buildField(controller: _confirmCtrl, label: 'Confirm Password', icon: Icons.lock_outline, obscure: true),
              const SizedBox(height: 16),

              // Unit Number
              _buildField(controller: _unitCtrl, label: 'Unit Number', icon: Icons.home),
              const SizedBox(height: 16),

              // Contact Number
              _buildField(controller: _contactCtrl, label: 'Contact Number', icon: Icons.phone, keyboard: TextInputType.phone,inputFormatters: [FilteringTextInputFormatter.digitsOnly],),
              const SizedBox(height: 20),

              // Proof upload
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: Text('Upload Title Deed', style: GoogleFonts.montserrat()),
                    onPressed: _pickProof,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _proofFile == null ? 'No file selected' : _proofFile!.path.split('/').last,
                      style: GoogleFonts.montserrat(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _registerOwner,
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      : Text('Register', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 16),

              // Back to login
              TextButton(
                onPressed: _isLoading ? null : () => context.go('/login'),
                child: Text(
                  'Already have an account? Login',
                  style: GoogleFonts.montserrat(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
