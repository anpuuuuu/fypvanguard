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
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _imageFile;
  bool _isUploading = false;
  String _selectedPriority = 'medium';
  String _selectedCategory = 'general';
  
  final List<String> _priorities = ['low', 'medium', 'high', 'urgent'];
  final List<String> _categories = [
    'general',
    'plumbing',
    'electrical',
    'hvac',
    'structural',
    'other'
  ];

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
        priority: _selectedPriority,
        category: _selectedCategory,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );
      _descCtrl.clear();
      _locationCtrl.clear();
      setState(() {
        _imageFile = null;
        _selectedPriority = 'medium';
        _selectedCategory = 'general';
      });
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

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'plumbing':
        return 'Plumbing';
      case 'electrical':
        return 'Electrical';
      case 'hvac':
        return 'HVAC';
      case 'structural':
        return 'Structural';
      case 'general':
        return 'General';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
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
                      // Priority Selection
                      Text(
                        'Priority',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _priorities.map((priority) {
                          final isSelected = _selectedPriority == priority;
                          return FilterChip(
                            label: Text(
                              _getPriorityLabel(priority),
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedPriority = priority);
                            },
                            backgroundColor: Colors.grey[200],
                            selectedColor: _getPriorityColor(priority),
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Category Selection
                      Text(
                        'Category',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade700),
                          ),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(
                              _getCategoryLabel(category),
                              style: GoogleFonts.montserrat(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Location (optional)
                      TextField(
                        controller: _locationCtrl,
                        decoration: InputDecoration(
                          labelText: 'Location (Optional)',
                          hintText: 'e.g., Unit 101, Kitchen, Bathroom',
                          labelStyle: GoogleFonts.montserrat(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade700),
                          ),
                        ),
                        style: GoogleFonts.montserrat(),
                      ),
                      const SizedBox(height: 16),
                      // Description
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
                        maxLines: 4,
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
                      final status = (data['status'] as String).toLowerCase();
                      final priority = data['priority'] as String? ?? 'medium';
                      final category = data['category'] as String? ?? 'general';
                      final location = data['location'] as String?;
                      final ts = (data['createdAt'] as Timestamp?)
                          ?.toDate()
                          ?.toLocal();
                      final dateStr = ts == null
                          ? ''
                          : DateFormat('dd MMM yyyy HH:mm').format(ts);

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

                      Color _getPriorityColor(String p) {
                        switch (p) {
                          case 'urgent': return Colors.red;
                          case 'high': return Colors.orange;
                          case 'medium': return Colors.blue;
                          case 'low': return Colors.green;
                          default: return Colors.grey;
                        }
                      }

                      String _getPriorityLabel(String p) {
                        return p.substring(0, 1).toUpperCase() + p.substring(1);
                      }

                      String _getCategoryLabel(String c) {
                        switch (c) {
                          case 'plumbing': return 'Plumbing';
                          case 'electrical': return 'Electrical';
                          case 'hvac': return 'HVAC';
                          case 'structural': return 'Structural';
                          case 'general': return 'General';
                          case 'other': return 'Other';
                          default: return c;
                        }
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(desc,
                                            style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
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
                                                  fontSize: 10,
                                                  color: _getPriorityColor(priority),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getCategoryLabel(category),
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 10,
                                                  color: Colors.blue[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('$dateStr',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.grey[700])),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: color,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              if (location != null && location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text('Location: $location',
                                        style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: Colors.grey[700])),
                                  ],
                                ),
                              ],
                              if (thumb != null) ...[
                                const SizedBox(height: 8),
                                thumb,
                              ],
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
