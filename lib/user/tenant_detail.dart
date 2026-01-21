// lib/user/tenant_detail.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class TenantDetailPage extends StatefulWidget {
  final Map<String, dynamic> tenant;
  const TenantDetailPage({Key? key, required this.tenant}) : super(key: key);

  @override
  _TenantDetailPageState createState() => _TenantDetailPageState();
}

class _TenantDetailPageState extends State<TenantDetailPage> {
  late String tenantId;
  late String fullName, contact, unit;
  String createdStr = '-';

  @override
  void initState() {
    super.initState();
    final data = widget.tenant;
    tenantId = data['residentId'] as String? ?? '';
    fullName = data['fullName'] as String? ?? '-';
    contact  = data['contactNumber'] as String? ?? '-';
    unit     = data['unitNumber']  as String? ?? '-';
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      final dt = raw.toDate().toLocal();
      createdStr =
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Remove Tenant', style: GoogleFonts.montserrat()),
        content: Text('Are you sure you want to remove $fullName?', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.montserrat()), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text('Remove', style: GoogleFonts.montserrat(color: Colors.red)), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true) return;

    // Soft‐delete: mark accounts status inactive
    await FirebaseFirestore.instance
        .collection('accounts')
        .doc(tenantId)
        .update({'status': 'inactive'});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fullName has been removed')),
    );
    Navigator.pop(context);
  }

  Future<void> _editTenant() async {
    final nameCtrl = TextEditingController(text: fullName);
    final contactCtrl = TextEditingController(text: contact);

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Tenant', style: GoogleFonts.montserrat()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              decoration: InputDecoration(labelText: 'Contact #', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(child: Text('Cancel', style: GoogleFonts.montserrat()), onPressed: () => Navigator.pop(context,false)),
          TextButton(child: Text('Save', style: GoogleFonts.montserrat()), onPressed: () => Navigator.pop(context,true)),
        ],
      ),
    );
    if (saved == true) {
      final newName = nameCtrl.text.trim();
      final newContact = contactCtrl.text.trim();
      await FirebaseFirestore.instance.collection('residents').doc(tenantId).update({
        'fullName': newName,
        'contactNumber': newContact,
      });
      setState(() {
        fullName = newName;
        contact = newContact;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Tenant Details', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Header Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.red.shade700,
                        child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                            style: const TextStyle(color: Colors.white, fontSize: 24)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Unit $unit', style: GoogleFonts.montserrat(color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info Tiles
              _InfoTile(icon: Icons.phone, label: 'Contact', value: contact),
              _InfoTile(icon: Icons.home,  label: 'Unit',    value: unit),
              _InfoTile(icon: Icons.calendar_today, label: 'Joined', value: createdStr),

              const Spacer(),

              // Actions
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: Text('Edit Tenant', style: GoogleFonts.montserrat()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _editTenant,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: Text('Remove Tenant', style: GoogleFonts.montserrat(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade700),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _confirmRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: Colors.red.shade700),
        title: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: GoogleFonts.montserrat()),
      ),
    );
  }
}
