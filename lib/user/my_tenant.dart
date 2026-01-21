// lib/user/my_tenant.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vanguard/user/tenant_detail.dart';
import 'RegisterVisitorForm.dart';

class MyTenantPage extends StatefulWidget {
  const MyTenantPage({Key? key}) : super(key: key);

  @override
  _MyTenantPageState createState() => _MyTenantPageState();
}

class _MyTenantPageState extends State<MyTenantPage> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final ownerSnap = await FirebaseFirestore.instance
          .collection('residents')
          .doc(user.uid)
          .get();

      final unitNumber = ownerSnap.data()?['unitNumber'] as String? ?? '';
      if (unitNumber.isEmpty) {
        setState(() {
          _tenants = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch all residents in this unit
      final tenantsSnap = await FirebaseFirestore.instance
          .collection('residents')
          .where('unitNumber', isEqualTo: unitNumber)
          .get();

      final List<Map<String, dynamic>> tenants = [];
      for (final doc in tenantsSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['residentId'] = doc.id;

        // Load their account data
        final acctSnap = await FirebaseFirestore.instance
            .collection('accounts')
            .doc(doc.id)
            .get();
        final acct = acctSnap.data() ?? {};
        final role   = acct['role']   as String? ?? '';
        final status = acct['status'] as String? ?? 'inactive';

        // Only tenants (but include both active and inactive)
        if (role == 'tenant') {
          data['status'] = status;
          tenants.add(data);
        }
      }

      setState(() {
        _tenants = tenants;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tenants: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reactivateTenant(String tenantId) async {
    await FirebaseFirestore.instance
        .collection('accounts')
        .doc(tenantId)
        .update({'status': 'active'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tenant reactivated')),
    );
    _loadTenants();
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
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const RegisterVisitorForm(entryType: 'walk-in'),
                ));
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.directions_car),
              label: Text('By Car', style: GoogleFonts.montserrat()),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const RegisterVisitorForm(entryType: 'car'),
                ));
              },
            ),
          ],
        ),
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
        title: Text('My Tenants', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.red.shade700))
          : _tenants.isEmpty
          ? Center(
        child: Text('You have no tenants.',
            style: GoogleFonts.montserrat(color: Colors.grey)),
      )
          : RefreshIndicator(
        onRefresh: _loadTenants,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tenants.length,
          itemBuilder: (context, i) {
            final tenant = _tenants[i];
            final fullName = (tenant['fullName'] as String?) ?? '';
            final contact  = (tenant['contactNumber'] as String?) ?? '-';
            final unit     = (tenant['unitNumber']   as String?) ?? '-';
            final status   = (tenant['status']       as String?) ?? 'inactive';
            final isActive = status == 'active';

            // Avatar initial
            final initial = fullName.isNotEmpty
                ? fullName[0].toUpperCase()
                : '?';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.grey,
                  child: Text(initial, style: const TextStyle(color: Colors.white)),
                ),
                title: Text(
                  fullName.isNotEmpty ? fullName : 'No Name',
                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Contact: $contact', style: GoogleFonts.montserrat(fontSize: 14)),
                    Text('Unit: $unit',         style: GoogleFonts.montserrat(fontSize: 14)),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.montserrat(
                            color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: isActive
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      onDeleted: isActive
                          ? null
                          : () => _reactivateTenant(tenant['residentId'] as String),
                      deleteIcon: isActive
                          ? null
                          : const Icon(Icons.refresh, size: 18, color: Colors.red),
                      deleteButtonTooltipMessage: isActive
                          ? null
                          : 'Reactivate',
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: isActive
                    ? const Icon(Icons.arrow_forward_ios)
                    : null,
                onTap: isActive
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TenantDetailPage(tenant: tenant),
                    ),
                  );
                }
                    : null,
              ),
            );
          },
        ),
      ),

      // ─── “Register Tenant” FAB ─────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        onPressed: () => GoRouter.of(context).go('/tenantregister'),
        child: const Icon(Icons.add),
        tooltip: 'Register Tenant',
      ),

      // ─── Bottom Navigation ───────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Home
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
