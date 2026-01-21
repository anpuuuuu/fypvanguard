// lib/admin/user_management.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _selectedRole = 'All';
  final _searchCtrl = TextEditingController();
  final _allRoles = ['All', 'owner', 'tenant', 'security', 'admin'];
  final CollectionReference _accounts =
  FirebaseFirestore.instance.collection('accounts');

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  Future<void> _showAddUserDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'security';
    String status = 'active';
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text('Add Account', style: GoogleFonts.montserrat()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['security', 'admin']
                      .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.capitalize(), style: GoogleFonts.montserrat()),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => role = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['active', 'inactive']
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.capitalize(), style: GoogleFonts.montserrat()),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => status = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel', style: GoogleFonts.montserrat()),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text('Create', style: GoogleFonts.montserrat()),
                onPressed: isLoading
                    ? null
                    : () async {
                  final email = emailCtrl.text.trim();
                  final pwd = passCtrl.text;
                  if (email.isEmpty || pwd.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All fields are required')),
                    );
                    return;
                  }
                  setState(() => isLoading = true);
                  try {
                    // 1) create auth user
                    final cred = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(email: email, password: pwd);
                    final uid = cred.user!.uid;

                    // 2) write accounts doc
                    await _accounts.doc(uid).set({
                      'username': email,
                      'role': role,
                      'residentId': uid,
                      'status': status,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${role.capitalize()} added')),
                    );
                    Navigator.pop(ctx);
                    setState(() {}); // refresh list
                  } on FirebaseAuthException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: ${e.message}')),
                    );
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show full resident info (for owner/tenant)
  Future<void> _showUserProfile(String uid) async {
    final acctSnap = await _accounts.doc(uid).get();
    final resSnap =
    await FirebaseFirestore.instance.collection('residents').doc(uid).get();

    final acct = acctSnap.data()! as Map<String, dynamic>;
    final res = resSnap.data()! as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(res['fullName'] ?? 'Profile', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${acct['username']}', style: GoogleFonts.montserrat()),
            const SizedBox(height: 8),
            Text('Role: ${acct['role']}', style: GoogleFonts.montserrat()),
            const SizedBox(height: 8),
            Text('Status: ${acct['status']}', style: GoogleFonts.montserrat()),
            const Divider(),
            Text('Full Name: ${res['fullName'] ?? '-'}', style: GoogleFonts.montserrat()),
            const SizedBox(height: 8),
            Text('Contact: ${res['contactNumber'] ?? '-'}', style: GoogleFonts.montserrat()),
            const SizedBox(height: 8),
            Text('Unit: ${res['unitNumber'] ?? '-'}', style: GoogleFonts.montserrat()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.montserrat()),
          )
        ],
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
        title: Text('User Management',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Filter & Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    underline: const SizedBox(),
                    items: _allRoles
                        .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.capitalize(), style: GoogleFonts.montserrat()),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      hintText: 'Search by email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _accounts.orderBy('createdAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs.where((doc) {
                  final d = doc.data()! as Map<String, dynamic>;
                  final email = (d['username'] ?? '').toString().toLowerCase();
                  final role = (d['role'] ?? '').toString();
                  if (_selectedRole != 'All' && role != _selectedRole) return false;
                  final search = _searchCtrl.text.toLowerCase();
                  return search.isEmpty || email.contains(search);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No users found.', style: GoogleFonts.montserrat(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data()! as Map<String, dynamic>;
                    final email = d['username'] as String? ?? '';
                    final role = d['role'] as String? ?? '';
                    final status = d['status'] as String? ?? '';

                    final avatar = CircleAvatar(
                      backgroundColor: Colors.red.shade700,
                      child: Text(
                        email.isNotEmpty ? email[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                    final statusColor = status == 'active' ? Colors.green : Colors.grey;
                    final statusChip = Chip(
                      label: Text(status.capitalize()),
                      backgroundColor: statusColor.shade50,
                      labelStyle: TextStyle(color: statusColor),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        leading: avatar,
                        title: Text(email,
                            style: GoogleFonts.montserrat(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        subtitle: Wrap(spacing: 8, children: [
                          Chip(
                            label: Text(role.capitalize()),
                            backgroundColor: Colors.blue.shade50,
                            labelStyle: const TextStyle(color: Colors.blue),
                          ),
                          statusChip,
                        ]),
                        trailing: PopupMenuButton<String>(
                          onSelected: (choice) async {
                            if (choice == 'ToggleStatus' &&
                                (role == 'security' || role == 'admin')) {
                              final newStatus = status == 'active' ? 'inactive' : 'active';
                              await _accounts.doc(doc.id).update({'status': newStatus});
                            } else if (choice == 'ViewProfile' &&
                                (role == 'owner' || role == 'tenant')) {
                              await _showUserProfile(doc.id);
                            }
                            setState(() {});
                          },
                          itemBuilder: (_) => [
                            if (role == 'security' || role == 'admin')
                              PopupMenuItem(
                                value: 'ToggleStatus',
                                child: Text(
                                  status == 'active' ? 'Deactivate' : 'Activate',
                                  style: TextStyle(
                                      color: status == 'active'
                                          ? Colors.red
                                          : Colors.green),
                                ),
                              ),
                            if (role == 'owner' || role == 'tenant')
                              const PopupMenuItem(
                                  value: 'ViewProfile',
                                  child: Text('View Profile')),
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add),
        onPressed: _showAddUserDialog,
        tooltip: 'Add Security/Admin',
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex:2, // Users tab
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

/// Simple extension to capitalize
extension StringCapital on String {
  String capitalize() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : this;
}
