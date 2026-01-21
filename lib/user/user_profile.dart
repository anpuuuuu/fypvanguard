// lib/user/user_profile.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String _fullName = '';
  String _email = '';
  String _contactNumber = '';
  String _unitNumber = '';
  String _proofBase64 = '';
  String _role = '';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();

  final TextEditingController _oldPwdCtrl = TextEditingController();
  final TextEditingController _newPwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();

  bool _editingName = false;
  bool _editingContact = false;
  bool _isSaving = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final acctSnap = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(user.uid)
        .get();
    final resSnap = await FirebaseFirestore.instance
        .collection('residents')
        .doc(user.uid)
        .get();

    final acct = acctSnap.data() ?? {};
    final res = resSnap.data() ?? {};

    setState(() {
      _email = acct['username'] as String? ?? '';
      _fullName = res['fullName'] as String? ?? '';
      _contactNumber = res['contactNumber'] as String? ?? '';
      _unitNumber = res['unitNumber'] as String? ?? '';
      _proofBase64 = res['proofDocBase64'] as String? ?? '';
      _role = acct['role'] as String? ?? '';

      _nameCtrl.text = _fullName;
      _contactCtrl.text = _contactNumber;
    });
  }

  Future _saveField(String field) async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = FirebaseFirestore.instance
        .collection('residents')
        .doc(user.uid);

    try {
      if (field == 'name') {
        final newName = _nameCtrl.text.trim();
        await doc.update({'fullName': newName});
        setState(() => _fullName = newName);
      } else {
        final newContact = _contactCtrl.text.trim();
        await doc.update({'contactNumber': newContact});
        setState(() => _contactNumber = newContact);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(field == 'name' ? 'Name updated' : 'Contact updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
        if (field == 'name') _editingName = false;
        if (field == 'contact') _editingContact = false;
      });
    }
  }

  Future _showChangePasswordDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPwdCtrl,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPwdCtrl,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPwdCtrl,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isChangingPassword ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isChangingPassword ? null : _changePassword,
            child: _isChangingPassword
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future _changePassword() async {
    final oldPwd = _oldPwdCtrl.text.trim();
    final newPwd = _newPwdCtrl.text.trim();
    final confirm = _confirmPwdCtrl.text.trim();

    if (oldPwd.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields')),
      );
      return;
    }
    if (newPwd != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPwd,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPwd);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error changing password')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isChangingPassword = false);
      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
      _confirmPwdCtrl.clear();
    }
  }

  Widget _buildEditableCard({
    required String title,
    required String value,
    required TextEditingController controller,
    required bool editing,
    required VoidCallback onToggle,
    required VoidCallback onSave,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: editing
                  ? TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: title,
                  labelStyle: GoogleFonts.montserrat(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red.shade700),
                  ),
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: GoogleFonts.montserrat()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            editing
                ? (_isSaving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: onSave,
            ))
                : IconButton(
              icon: const Icon(Icons.edit, color: Colors.red),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyCard(String title, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: GoogleFonts.montserrat()),
      ),
    );
  }

  Widget _buildProofCard() {
    if (_proofBase64.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text('Proof Document', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          subtitle: Text('Not uploaded', style: GoogleFonts.montserrat(color: Colors.grey)),
        ),
      );
    }
    final bytes = base64Decode(_proofBase64);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.black,
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          );
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Proof Document', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Image.memory(bytes, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        title: Text('Profile', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildEditableCard(
              title: 'Full Name',
              value: _fullName,
              controller: _nameCtrl,
              editing: _editingName,
              onToggle: () => setState(() => _editingName = true),
              onSave: () => _saveField('name'),
            ),
            const SizedBox(height: 16),
            _buildEditableCard(
              title: 'Contact Number',
              value: _contactNumber,
              controller: _contactCtrl,
              editing: _editingContact,
              onToggle: () => setState(() => _editingContact = true),
              onSave: () => _saveField('contact'),
            ),
            const SizedBox(height: 16),
            _buildReadOnlyCard('Email', _email),
            const SizedBox(height: 16),
            _buildReadOnlyCard('Unit Number', _unitNumber),
if (_role == 'owner') ...[
        const SizedBox(height: 16),
         _buildProofCard(),
        ],
            const SizedBox(height: 16),
            // Change Password
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.lock, color: Colors.red.shade700),
                title: Text('Change Password', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                onTap: _showChangePasswordDialog,
              ),
            ),
          ],
        ),
      ),

      // ─── Bottom Navigation ───────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4, // Profile
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
            // show visitor dialog
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
                          GoRouter.of(context).push('/user/registerVisitor?type=walk-in');
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.directions_car),
                        label: Text('By Car', style: GoogleFonts.montserrat()),
                        onPressed: () {
                          Navigator.pop(context);
                          GoRouter.of(context).push('/user/registerVisitor?type=car');
                        },
                      ),
                    ],
                  ),
                ),
              );
              break;
            case 2:
              GoRouter.of(context).go('/user/bookFacility');
              break;
            case 3:
              GoRouter.of(context).go('/user/maintenanceRequest');
              break;
            case 4:
            // already here
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
