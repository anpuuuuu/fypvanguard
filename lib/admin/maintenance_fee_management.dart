// lib/admin/maintenance_fee_management.dart
// Admin page to push maintenance fees to residents

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../payment/models/payment_type_model.dart';
import '../payment/services/payment_type_service.dart';

class MaintenanceFeeManagementPage extends StatefulWidget {
  const MaintenanceFeeManagementPage({Key? key}) : super(key: key);

  @override
  State<MaintenanceFeeManagementPage> createState() => _MaintenanceFeeManagementPageState();
}

class _MaintenanceFeeManagementPageState extends State<MaintenanceFeeManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final PaymentTypeService _paymentTypeService = PaymentTypeService();
  
  List<PaymentType> _paymentTypes = [];
  PaymentType? _selectedPaymentType;
  String _targetType = 'all'; // 'all' or 'specific'
  List<String> _selectedResidentIds = [];
  List<Map<String, dynamic>> _allResidents = [];
  bool _isLoading = false;
  bool _isLoadingResidents = true;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _loadResidents();
    _loadPaymentTypes();
    // Set default due date to 30 days from now
    _selectedDueDate = DateTime.now().add(const Duration(days: 30));
    _dueDateController.text = DateFormat('yyyy-MM-dd').format(_selectedDueDate!);
  }

  Future<void> _loadPaymentTypes() async {
    try {
      final types = await _paymentTypeService.getPaymentTypes();
      setState(() {
        _paymentTypes = types;
        _selectedPaymentType = types.isNotEmpty ? types.first : null;
      });
    } catch (e) {
      debugPrint('Failed to load payment types: $e');
      setState(() {
        _paymentTypes = defaultPaymentTypes;
        _selectedPaymentType = defaultPaymentTypes.isNotEmpty ? defaultPaymentTypes.first : null;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _loadResidents() async {
    setState(() => _isLoadingResidents = true);
    try {
      // Get all active residents (owners and tenants)
      final accountsSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('status', isEqualTo: 'approved')
          .where('role', whereIn: ['owner', 'tenant'])
          .get();

      final residents = <Map<String, dynamic>>[];
      
      for (var accountDoc in accountsSnapshot.docs) {
        final accountData = accountDoc.data();
        final residentId = accountData['residentId'] as String? ?? accountDoc.id;
        
        // Get resident details
        final residentDoc = await FirebaseFirestore.instance
            .collection('residents')
            .doc(residentId)
            .get();
        
        if (residentDoc.exists) {
          final residentData = residentDoc.data()!;
          residents.add({
            'id': residentId,
            'accountId': accountDoc.id,
            'name': residentData['fullName'] as String? ?? 'Unknown',
            'unitNumber': residentData['unitNumber'] as String? ?? 'N/A',
            'role': accountData['role'] as String? ?? 'owner',
          });
        }
      }

      setState(() {
        _allResidents = residents;
        _isLoadingResidents = false;
      });
    } catch (e) {
      setState(() => _isLoadingResidents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load residents: $e')),
        );
      }
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pushFees() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_targetType == 'specific' && _selectedResidentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one resident')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim();
      final dueDate = _selectedDueDate!;

      // Determine target residents
      final targetResidents = _targetType == 'all'
          ? _allResidents
          : _allResidents.where((r) => _selectedResidentIds.contains(r['id'])).toList();

      int successCount = 0;
      int failCount = 0;

      // Push fee to each resident
      for (var resident in targetResidents) {
        try {
          final residentId = resident['id'] as String;
          
          // Create pending fee document
          await FirebaseFirestore.instance
              .collection('pendingFees')
              .add({
            'residentId': residentId,
            'amount': amount,
            'feeType': _selectedPaymentType?.key ?? 'maintenance',
            'description': description,
            'dueDate': Timestamp.fromDate(dueDate),
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
            'status': 'pending',
          });

          successCount++;

          // Notification will be sent via Cloud Functions when pendingFees document is created
          // For now, we'll just log it
          debugPrint('Maintenance fee created for ${resident['name']}');
        } catch (e) {
          failCount++;
          print('Failed to push fee to ${resident['name']}: $e');
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully pushed fees to $successCount resident(s)${failCount > 0 ? '. Failed: $failCount' : ''}',
            ),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );

        // Clear form
        _amountController.clear();
        _descriptionController.clear();
        _selectedResidentIds.clear();
        _targetType = 'all';
        _selectedDueDate = DateTime.now().add(const Duration(days: 30));
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(_selectedDueDate!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to push fees: $e')),
        );
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
        title: Text(
          'Maintenance Fee Management',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: _isLoadingResidents
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment type selection
                    Text(
                      'Payment Type',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PaymentType>(
                          value: _selectedPaymentType,
                          isExpanded: true,
                          hint: Text('Select payment type', style: GoogleFonts.montserrat()),
                          items: _paymentTypes.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text('${t.displayName}${t.description.isNotEmpty ? ' - ${t.description}' : ''}', style: GoogleFonts.montserrat()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedPaymentType = value);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Amount input
                    Text(
                      'Amount (RM)',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Description input
                    Text(
                      'Description',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter fee description...',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter description';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Due date input
                    Text(
                      'Due Date',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dueDateController,
                      readOnly: true,
                      onTap: _selectDueDate,
                      decoration: InputDecoration(
                        hintText: 'Select due date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Target type selection
                    Text(
                      'Target Residents',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('All Residents', style: GoogleFonts.montserrat()),
                            value: 'all',
                            groupValue: _targetType,
                            onChanged: (value) {
                              setState(() {
                                _targetType = value!;
                                _selectedResidentIds.clear();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Specific Residents', style: GoogleFonts.montserrat()),
                            value: 'specific',
                            groupValue: _targetType,
                            onChanged: (value) {
                              setState(() => _targetType = value!);
                            },
                          ),
                        ),
                      ],
                    ),

                    // Resident selection (if specific)
                    if (_targetType == 'specific') ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Select Residents',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_selectedResidentIds.length} selected',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  itemCount: _allResidents.length,
                                  itemBuilder: (context, index) {
                                    final resident = _allResidents[index];
                                    final isSelected = _selectedResidentIds.contains(resident['id']);
                                    return CheckboxListTile(
                                      title: Text(
                                        resident['name'] as String,
                                        style: GoogleFonts.montserrat(),
                                      ),
                                      subtitle: Text(
                                        'Unit ${resident['unitNumber']} - ${resident['role']}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      value: isSelected,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedResidentIds.add(resident['id'] as String);
                                          } else {
                                            _selectedResidentIds.remove(resident['id'] as String);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Summary card
                    Card(
                      elevation: 2,
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summary',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'Payment Type',
                              _selectedPaymentType?.displayName ?? '-',
                            ),
                            _buildSummaryRow(
                              'Amount',
                              _amountController.text.isNotEmpty
                                  ? 'RM ${double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? '0.00'}'
                                  : 'RM 0.00',
                            ),
                            _buildSummaryRow(
                              'Target',
                              _targetType == 'all'
                                  ? 'All Residents (${_allResidents.length})'
                                  : 'Specific Residents (${_selectedResidentIds.length})',
                            ),
                            _buildSummaryRow(
                              'Due Date',
                              _dueDateController.text.isNotEmpty
                                  ? _dueDateController.text
                                  : 'Not set',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Push button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _pushFees,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Push Fees',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
