// lib/user/reupload_proof.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ReuploadProofPage extends StatefulWidget {
  const ReuploadProofPage({Key? key}) : super(key: key);

  @override
  _ReuploadProofPageState createState() => _ReuploadProofPageState();
}

class _ReuploadProofPageState extends State<ReuploadProofPage> {
  File? _proofFile;
  bool _uploading = false;

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (file != null) setState(() => _proofFile = File(file.path));
  }

  Future<void> _submit() async {
    if (_proofFile == null) return;
    setState(() => _uploading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final bytes = await _proofFile!.readAsBytes();
    final base64Img = base64Encode(bytes);

    // 1) update residents proof
    await FirebaseFirestore.instance
        .collection('residents')
        .doc(uid)
        .update({'proofDocBase64': base64Img});

    // 2) reset account status to pending
    await FirebaseFirestore.instance
        .collection('accounts')
        .doc(uid)
        .update({'status': 'pending'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proof re-uploaded. Waiting for approval.')),
    );

    context.go('/user/pendingApproval');
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Re-upload Title Deed',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: _logout,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Instruction Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your title deed was rejected by the admin. '
                          'Please select and re-upload a valid proof document.',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Choose file button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.upload_file),
              label: Text('Choose Proof Document', style: GoogleFonts.montserrat()),
              onPressed: _pickProof,
            ),

            const SizedBox(height: 16),

            // Selected file name
            Text(
              _proofFile == null ? 'No file selected' : _proofFile!.path.split('/').last,
              style: GoogleFonts.montserrat(color: Colors.grey[700]),
            ),

            const Spacer(),

            // Re-upload button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _uploading ? null : _submit,
                child: _uploading
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : Text(
                  'Re-upload and Submit',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
