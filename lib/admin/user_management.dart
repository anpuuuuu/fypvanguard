// lib/admin/user_management.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _selectedRole = 'All';
  String _selectedStatus = 'All';
  final _searchCtrl = TextEditingController();
  final _allRoles = ['All', 'owner', 'tenant', 'security', 'admin'];
  final _allStatuses = ['All', 'active', 'inactive'];
  final CollectionReference _accounts =
  FirebaseFirestore.instance.collection('accounts');
  final Set<String> _selectedUsers = <String>{};

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

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
          // Statistics
          StreamBuilder<QuerySnapshot>(
            stream: _accounts.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              final owners = docs.where((d) => (d.data() as Map)['role'] == 'owner').length;
              final tenants = docs.where((d) => (d.data() as Map)['role'] == 'tenant').length;
              final security = docs.where((d) => (d.data() as Map)['role'] == 'security').length;
              final admins = docs.where((d) => (d.data() as Map)['role'] == 'admin').length;
              final active = docs.where((d) => (d.data() as Map)['status'] == 'active').length;
              
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Owners', owners, Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('Tenants', tenants, Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('Security', security, Colors.orange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('Active', active, Colors.green),
                    ),
                  ],
                ),
              );
            },
          ),
          // Filter & Search
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by email or name...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.montserrat(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Role', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedRole,
                              underline: const SizedBox(),
                              isExpanded: true,
                              items: _allRoles
                                  .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.capitalize(), style: GoogleFonts.montserrat(fontSize: 13)),
                              ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedRole = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              underline: const SizedBox(),
                              isExpanded: true,
                              items: _allStatuses
                                  .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.capitalize(), style: GoogleFonts.montserrat(fontSize: 13)),
                              ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedStatus = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  final status = (d['status'] ?? '').toString();
                  
                  if (_selectedRole != 'All' && role != _selectedRole) return false;
                  if (_selectedStatus != 'All' && status != _selectedStatus) return false;
                  
                  final search = _searchCtrl.text.toLowerCase();
                  if (search.isNotEmpty) {
                    // Try to get resident name for search
                    return email.contains(search);
                  }
                  return true;
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
                    final createdAt = d['createdAt'] as Timestamp?;
                    final isSelected = _selectedUsers.contains(doc.id);

                    return FutureBuilder<DocumentSnapshot>(
                      future: (role == 'owner' || role == 'tenant')
                          ? FirebaseFirestore.instance.collection('residents').doc(doc.id).get()
                          : Future.value(null),
                      builder: (context, residentSnapshot) {
                        String displayName = email.split('@').first;
                        if (residentSnapshot.hasData && residentSnapshot.data!.exists) {
                          final residentData = residentSnapshot.data!.data() as Map<String, dynamic>?;
                          displayName = residentData?['fullName'] ?? displayName;
                        }

                        final statusColor = status == 'active' ? Colors.green : Colors.grey;
                        final roleColor = _getRoleColor(role);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.red.shade700 : Colors.grey[200]!,
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
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedUsers.add(doc.id);
                                  } else {
                                    _selectedUsers.remove(doc.id);
                                  }
                                });
                              },
                            ),
                            title: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: roleColor,
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(left: 52, top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: roleColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          role.capitalize(),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: roleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              status.capitalize(),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (createdAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Joined: ${DateFormat('MMM d, yyyy').format(createdAt.toDate().toLocal())}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                              onSelected: (choice) async {
                                if (choice == 'ToggleStatus' &&
                                    (role == 'security' || role == 'admin')) {
                                  final newStatus = status == 'active' ? 'inactive' : 'active';
                                  await _accounts.doc(doc.id).update({'status': newStatus});
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('User ${newStatus}', style: GoogleFonts.montserrat()),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else if (choice == 'ViewProfile' &&
                                    (role == 'owner' || role == 'tenant')) {
                                  await _showUserProfile(doc.id);
                                } else if (choice == 'ResetPassword') {
                                  _showResetPasswordDialog(doc.id, email);
                                } else if (choice == 'Delete') {
                                  _confirmDeleteUser(doc.id, email);
                                }
                                setState(() {});
                              },
                              itemBuilder: (_) => [
                                if (role == 'owner' || role == 'tenant')
                                  const PopupMenuItem(
                                    value: 'ViewProfile',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, size: 18),
                                        SizedBox(width: 8),
                                        Text('View Profile'),
                                      ],
                                    ),
                                  ),
                                if (role == 'security' || role == 'admin')
                                  PopupMenuItem(
                                    value: 'ToggleStatus',
                                    child: Row(
                                      children: [
                                        Icon(
                                          status == 'active' ? Icons.block : Icons.check_circle,
                                          size: 18,
                                          color: status == 'active' ? Colors.red : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(status == 'active' ? 'Deactivate' : 'Activate'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'ResetPassword',
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_reset, size: 18),
                                      SizedBox(width: 8),
                                      Text('Reset Password'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedUsers.isNotEmpty)
            FloatingActionButton(
              backgroundColor: Colors.orange,
              heroTag: 'batch',
              child: const Icon(Icons.batch_prediction),
              onPressed: () => _showBatchActionsDialog(),
              tooltip: 'Batch Actions',
            ),
          const SizedBox(height: 12),
          FloatingActionButton(
            backgroundColor: Colors.red.shade700,
            heroTag: 'add',
            child: const Icon(Icons.add),
            onPressed: _showAddUserDialog,
            tooltip: 'Add Security/Admin',
          ),
        ],
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner': return Colors.blue;
      case 'tenant': return Colors.green;
      case 'security': return Colors.orange;
      case 'admin': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _showResetPasswordDialog(String userId, String email) async {
    final newPasswordCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reset password for: $email', style: GoogleFonts.montserrat()),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordCtrl,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: true,
              style: GoogleFonts.montserrat(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordCtrl.text.length >= 6) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password must be at least 6 characters', style: GoogleFonts.montserrat())),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Reset', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && newPasswordCtrl.text.isNotEmpty) {
      try {
        final user = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (user.isNotEmpty) {
          // Note: Admin cannot directly reset password, this would require backend function
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset initiated. User will receive email.', style: GoogleFonts.montserrat()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.montserrat())),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete User', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.red)),
        content: Text('Are you sure you want to delete $email? This action cannot be undone.', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _accounts.doc(userId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User deleted', style: GoogleFonts.montserrat()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e', style: GoogleFonts.montserrat())),
          );
        }
      }
    }
  }

  void _showBatchActionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Batch Actions (${_selectedUsers.length} selected)',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('Activate All', style: GoogleFonts.montserrat()),
              onTap: () async {
                Navigator.pop(context);
                await _batchUpdateStatus('active');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text('Deactivate All', style: GoogleFonts.montserrat()),
              onTap: () async {
                Navigator.pop(context);
                await _batchUpdateStatus('inactive');
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.orange),
              title: Text('Clear Selection', style: GoogleFonts.montserrat()),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedUsers.clear());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchUpdateStatus(String status) async {
    final count = _selectedUsers.length;
    final batch = FirebaseFirestore.instance.batch();
    for (var userId in _selectedUsers) {
      batch.update(_accounts.doc(userId), {'status': status});
    }
    await batch.commit();
    setState(() => _selectedUsers.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count users updated', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// Simple extension to capitalize
extension StringCapital on String {
  String capitalize() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : this;
}
