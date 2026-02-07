// lib/admin/payment_type_management.dart
// Admin page to manage payment types (maintenance, insurance, sinking, water bill, etc.)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../payment/models/payment_type_model.dart';
import '../payment/services/payment_type_service.dart';

class PaymentTypeManagementPage extends StatefulWidget {
  const PaymentTypeManagementPage({Key? key}) : super(key: key);

  @override
  State<PaymentTypeManagementPage> createState() => _PaymentTypeManagementPageState();
}

class _PaymentTypeManagementPageState extends State<PaymentTypeManagementPage> {
  final PaymentTypeService _service = PaymentTypeService();
  List<PaymentType> _types = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() => _loading = true);
    try {
      final types = await _service.getPaymentTypes();
      setState(() {
        _types = types;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({PaymentType? existing}) async {
    final keyCtrl = TextEditingController(text: existing?.key ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final orderCtrl = TextEditingController(text: existing?.order.toString() ?? '0');
    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Payment Type' : 'Add Payment Type', style: GoogleFonts.montserrat()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                decoration: InputDecoration(
                  labelText: 'Key (e.g. waterBill, electricBill)',
                  hintText: 'Lowercase, no spaces',
                ),
                enabled: !isEdit,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderCtrl,
                decoration: InputDecoration(labelText: 'Order'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = keyCtrl.text.trim().replaceAll(' ', '');
              final name = nameCtrl.text.trim();
              if (key.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Key and Display Name are required')),
                );
                return;
              }
              final order = int.tryParse(orderCtrl.text) ?? 0;
              final type = PaymentType(
                key: key,
                displayName: name,
                description: descCtrl.text.trim(),
                order: order,
              );
              try {
                if (isEdit) {
                  await _service.updatePaymentType(existing!.key, type);
                } else {
                  await _service.addPaymentType(type);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTypes();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Updated' : 'Added'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteType(PaymentType type) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Payment Type?', style: GoogleFonts.montserrat()),
        content: Text(
          'Delete "${type.displayName}"? Existing fees with this type will keep the key but may show as "Other".',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deletePaymentType(type.key);
        _loadTypes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Text('Payment Types', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure payment types for residents',
                        style: GoogleFonts.montserrat(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add),
                        label: Text('Add Payment Type', style: GoogleFonts.montserrat()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _types.length,
                    itemBuilder: (_, i) {
                      final t = _types[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade50,
                            child: Text('${t.order}', style: TextStyle(color: Colors.red.shade700)),
                          ),
                          title: Text(t.displayName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${t.key}${t.description.isNotEmpty ? ' · ${t.description}' : ''}',
                            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showAddEditDialog(existing: t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteType(t),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
