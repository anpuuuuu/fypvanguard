// lib/user/maintenance_request.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/maintenance_service.dart';
import 'RegisterVisitorForm.dart';

class MaintenanceRequestPage extends StatefulWidget {
  const MaintenanceRequestPage({Key? key}) : super(key: key);

  @override
  _MaintenanceRequestPageState createState() =>
      _MaintenanceRequestPageState();
}

class _MaintenanceRequestPageState extends State<MaintenanceRequestPage> {
  final _service = MaintenanceService();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _imageFile;
  bool _isUploading = false;

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _imageFile = picked);
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _imageFile = picked);
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue')),
      );
      return;
    }

    setState(() => _isUploading = true);

    String? base64Img;
    if (_imageFile != null) {
      final bytes = await File(_imageFile!.path).readAsBytes();
      base64Img = base64Encode(bytes);
    }

    try {
      await _service.createRequest(
        residentId: FirebaseAuth.instance.currentUser!.uid,
        description: desc,
        imageBase64: base64Img,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted')),
      );
      _descCtrl.clear();
      setState(() => _imageFile = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showEntryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Entry Type',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
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
                  MaterialPageRoute(
                      builder: (_) =>
                      const RegisterVisitorForm(entryType: 'walk-in')),
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
                  MaterialPageRoute(
                      builder: (_) =>
                      const RegisterVisitorForm(entryType: 'car')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Text('Maintenance Request',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Form
            Padding(
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
                      TextField(
                        controller: _descCtrl,
                        decoration: InputDecoration(
                          labelText: 'Describe issue',
                          labelStyle: GoogleFonts.montserrat(),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                            BorderSide(color: Colors.red.shade700),
                          ),
                        ),
                        maxLines: 3,
                        style: GoogleFonts.montserrat(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt),
                              label: Text(
                                  _imageFile == null
                                      ? 'Take Photo'
                                      : 'Retake Photo',
                                  style: GoogleFonts.montserrat()),
                              onPressed: _pickFromCamera,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library),
                              label: Text(
                                  _imageFile == null
                                      ? 'Upload Photo'
                                      : 'Change Photo',
                                  style: GoogleFonts.montserrat()),
                              onPressed: _pickFromGallery,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          if (_imageFile != null) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Image.file(File(_imageFile!.path),
                                  fit: BoxFit.cover),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _submit,
                          child: _isUploading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                              : Text('Submit Request',
                              style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // List of my requests
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _service.streamMyRequests(uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: GoogleFonts.montserrat()));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                        child: Text('No requests found.',
                            style: GoogleFonts.montserrat(
                                color: Colors.grey)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final data = docs[i].data()! as Map<String, dynamic>;
                      final desc = data['description'] as String? ?? '';
                      final status =
                      (data['status'] as String).toLowerCase();
                      final ts = (data['createdAt'] as Timestamp?)
                          ?.toDate()
                          ?.toLocal();
                      final dateStr = ts == null
                          ? ''
                          : DateFormat('dd MMM yyyy').format(ts);

                      Icon icon;
                      Color color;
                      switch (status) {
                        case 'in_progress':
                          icon = const Icon(Icons.build_circle,
                              color: Colors.orange);
                          color = Colors.orange;
                          break;
                        case 'resolved':
                          icon = const Icon(Icons.check_circle,
                              color: Colors.green);
                          color = Colors.green;
                          break;
                        default:
                          icon = const Icon(Icons.hourglass_empty,
                              color: Colors.grey);
                          color = Colors.grey;
                      }

                      final imageBase64 = data['imageBase64'] as String?;
                      Widget? thumb;
                      if (imageBase64 != null) {
                        thumb = Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InkWell(
                            onTap: () {
                              final bytes = base64Decode(imageBase64);
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  insetPadding: EdgeInsets.zero,
                                  backgroundColor: Colors.black,
                                  child: GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).pop(),
                                    child: InteractiveViewer(
                                      panEnabled: true,
                                      child: Image.memory(bytes,
                                          fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(imageBase64),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  icon,
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(desc,
                                        style: GoogleFonts.montserrat(
                                            fontSize: 14)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Date: $dateStr',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Text('Status: ${status.toUpperCase()}',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12, color: color)),
                              if (thumb != null) thumb,
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ─── Bottom Navigation ───────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3, // Maintenance
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
            // already on Maintenance
              break;
            case 4:
              GoRouter.of(context).go('/userprofile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_add), label: 'Visitor'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_available), label: 'Facility'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
