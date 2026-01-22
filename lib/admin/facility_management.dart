// lib/admin/facility_management.dart

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class FacilityManagementPage extends StatefulWidget {
  const FacilityManagementPage({Key? key}) : super(key: key);

  @override
  _FacilityManagementPageState createState() =>
      _FacilityManagementPageState();
}

class _FacilityManagementPageState extends State<FacilityManagementPage> {
  final _facilities = FirebaseFirestore.instance.collection('facilities');
  final _picker = ImagePicker();

  Future<void> _showEditDialog({
    String? docId,
    String initialName = '',
    String? initialImage,
    int? initialStartHour,
    int? initialEndHour,
    int? initialMaxSlots,
    bool initialActive = true,
  }) async {
    final isNew = docId == null;
    final _formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: initialName);

    String? base64Image = initialImage;
    int startHour = initialStartHour ?? 8;
    int endHour = initialEndHour ?? 18;
    int maxSlots = initialMaxSlots ?? 10;
    bool isActive = initialActive;
    bool _saving = false;

    await showDialog(
      context: context,
      barrierDismissible: _saving == false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            isNew ? 'New Facility' : 'Edit Facility',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Name
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Facility Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Image preview + picker
                if (base64Image != null) ...[
                  Image.memory(
                    base64Decode(base64Image!),
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.image),
                  label: Text(
                    base64Image == null ? 'Pick Image' : 'Change Image',
                    style: GoogleFonts.montserrat(),
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                    final file = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 600,
                    );
                    if (file != null) {
                      final bytes = await File(file.path).readAsBytes();
                      setState(() => base64Image = base64Encode(bytes));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Opening / Closing hours
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: startHour,
                      decoration: InputDecoration(
                        labelText: 'Opens at',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(24, (i) => i)
                          .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text('$h:00',
                            style: GoogleFonts.montserrat()),
                      ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => startHour = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: endHour,
                      decoration: InputDecoration(
                        labelText: 'Closes at',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(24, (i) => i)
                          .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text('$h:00',
                            style: GoogleFonts.montserrat()),
                      ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => endHour = v!),
                      validator: (v) => (v != null && v > startHour)
                          ? null
                          : 'Must be > open',
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Max Slots
                TextFormField(
                  initialValue: maxSlots.toString(),
                  decoration: InputDecoration(
                    labelText: 'Max Slots (per time period)',
                    border: OutlineInputBorder(),
                    helperText: 'How many bookings allowed at the same time',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return 'Must be at least 1';
                    return null;
                  },
                  onChanged: _saving
                      ? null
                      : (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) {
                            setState(() => maxSlots = n);
                          }
                        },
                ),
                const SizedBox(height: 16),

                // Active switch
                SwitchListTile(
                  title:
                  Text('Active', style: GoogleFonts.montserrat(fontSize: 14)),
                  value: isActive,
                  onChanged:
                  _saving ? null : (v) => setState(() => isActive = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.montserrat()),
              onPressed:
              _saving ? null : () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Text(isNew ? 'Create' : 'Save',
                  style: GoogleFonts.montserrat()),
              onPressed: _saving
                  ? null
                  : () async {
                if (!_formKey.currentState!.validate()) return;
                setState(() => _saving = true);

                try {
                                  final data = {
                                    'name': nameCtrl.text.trim(),
                                    'imageBase64': base64Image,
                                    'startHour': startHour,
                                    'endHour': endHour,
                                    'maxSlots': maxSlots,
                                    'active': isActive,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };
                  if (isNew) {
                    data['createdAt'] =
                        FieldValue.serverTimestamp();
                    await _facilities.add(data);
                  } else {
                    await _facilities.doc(docId).update(data);
                  }
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(
                    content: Text(
                        isNew
                            ? 'Facility created'
                            : 'Facility updated',
                        style: GoogleFonts.montserrat()),
                  ));
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(
                    content: Text('Error: $e',
                        style: GoogleFonts.montserrat()),
                    backgroundColor: Colors.red.shade300,
                  ));
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
        Text('Delete Facility?', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
              child:
              Text('Cancel', style: GoogleFonts.montserrat()),
              onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            child: Text('Delete',
                style: GoogleFonts.montserrat(color: Colors.red)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _facilities.doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Deleted',
              style: GoogleFonts.montserrat()),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting: $e',
              style: GoogleFonts.montserrat()),
          backgroundColor: Colors.red.shade300,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Facilities',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _facilities.orderBy('name').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('No facilities defined.',
                  style: GoogleFonts.montserrat(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data()! as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final start = data['startHour'] as int? ?? 0;
              final end = data['endHour'] as int? ?? start + 1;
              final slots = data['maxSlots'] as int? ?? 1;
              final active = data['active'] as bool? ?? true;
              final img64 = data['imageBase64'] as String?;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  leading: img64 != null
                      ? CircleAvatar(
                    backgroundImage:
                    MemoryImage(base64Decode(img64)),
                  )
                      : const CircleAvatar(child: Icon(Icons.room)),
                  title: Text(name,
                      style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Hours: ${start.toString().padLeft(2,'0')}:00 - ${end.toString().padLeft(2,'0')}:00\n'
                          'Slots: $slots  •  ${active ? 'Active' : 'Inactive'}',
                      style: GoogleFonts.montserrat()),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(
                          docId: d.id,
                          initialName: name,
                          initialImage: img64,
                          initialStartHour: start,
                          initialEndHour: end,
                          initialMaxSlots: slots,
                          initialActive: active,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(d.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add),
        onPressed: () => _showEditDialog(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:4, // Users tab
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/admin');
              break;
            case 1:
              GoRouter.of(context).go('/admin/ownerApprovals');
              break;
            case 2:
              GoRouter.of(context).go('/admin/userManagement');
              break;
            case 3:
              GoRouter.of(context).go('/admin/announcements');
              break;
            case 4:
              GoRouter.of(context).go('/admin/facilities');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Approvals'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Announcements'),
          BottomNavigationBarItem(icon: Icon(Icons.room_service), label: 'Facilities'),
        ],
      ),
    );
  }
}
