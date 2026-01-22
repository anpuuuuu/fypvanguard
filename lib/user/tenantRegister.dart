// lib/user/tenant_register.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TenantRegisterPage extends StatefulWidget {
  const TenantRegisterPage({Key? key}) : super(key: key);

  @override
  _TenantRegisterPageState createState() => _TenantRegisterPageState();
}

class _TenantRegisterPageState extends State<TenantRegisterPage> {
  final _emailCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _unitCtrl    = TextEditingController();
  final _rentCtrl    = TextEditingController();
  
  bool _isLoading    = false;
  String? _contactError;

  // ===== 租约相关字段 =====
  DateTime _leaseStartDate = DateTime.now();
  int _selectedLeaseMonths = 12; // 默认 12 个月
  final List<int> _leaseOptions = [6, 12, 24];
  bool _useCustomMonths = false;
  final _customMonthsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOwnerUnit();
  }

  Future<void> _loadOwnerUnit() async {
    final owner = FirebaseAuth.instance.currentUser;
    if (owner == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('residents')
        .doc(owner.uid)
        .get();
    final unit = snap.data()?['unitNumber'] as String? ?? '';
    _unitCtrl.text = unit;
  }

  /// 计算租约结束日期
  DateTime get _leaseEndDate {
    return DateTime(
      _leaseStartDate.year,
      _leaseStartDate.month + _selectedLeaseMonths,
      _leaseStartDate.day,
    );
  }

  /// 选择开始日期
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _leaseStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.red.shade700,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _leaseStartDate = picked);
    }
  }

  Future<void> _registerTenant() async {
    final email   = _emailCtrl.text.trim();
    final name    = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    final unit    = _unitCtrl.text.trim();
    final rentText = _rentCtrl.text.trim();

    if ([email, name, contact, unit].any((s) => s.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final phoneRe = RegExp(r'^\d{7,15}$');
    if (!phoneRe.hasMatch(contact)) {
      setState(() => _contactError = 'Enter 7–15 digits only');
      return;
    } else {
      setState(() => _contactError = null);
    }

    // 处理自定义月数
    if (_useCustomMonths) {
      final customMonths = int.tryParse(_customMonthsCtrl.text.trim());
      if (customMonths == null || customMonths < 1 || customMonths > 60) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid lease months (1-60)')),
        );
        return;
      }
      _selectedLeaseMonths = customMonths;
    }

    setState(() => _isLoading = true);
    try {
      // 1️⃣ Initialize a second FirebaseApp
      final secondaryApp = await Firebase.initializeApp(
        name: 'Secondary',
        options: Firebase.app().options,
      );

      // 2️⃣ Get its own Auth instance
      final secAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // 3️⃣ Create the tenant user under secondaryAuth (does NOT sign in primary)
      final cred = await secAuth.createUserWithEmailAndPassword(
        email: email,
        password: contact,
      );
      final tenantId = cred.user!.uid;

      // 4️⃣ 解析月租（可选）
      double? monthlyRent;
      if (rentText.isNotEmpty) {
        monthlyRent = double.tryParse(rentText);
      }

      // 5️⃣ Write tenant profile with lease info
      await FirebaseFirestore.instance
          .collection('residents')
          .doc(tenantId)
          .set({
        'fullName': name,
        'contactNumber': contact,
        'unitNumber': unit,
        'ownerId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        // ===== 租约信息 =====
        'leaseStartDate': Timestamp.fromDate(_leaseStartDate),
        'leaseEndDate': Timestamp.fromDate(_leaseEndDate),
        'leaseMonths': _selectedLeaseMonths,
        if (monthlyRent != null) 'monthlyRent': monthlyRent,
      });

      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(tenantId)
          .set({
        'username': email,
        'role': 'tenant',
        'status': 'active',
        'residentId': tenantId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6️⃣ Clean up secondaryAuth & secondaryApp
      await secAuth.signOut();
      await secondaryApp.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant registered successfully')),
      );
      GoRouter.of(context).go('/mytenant');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _unitCtrl.dispose();
    _rentCtrl.dispose();
    _customMonthsCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600]) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Register Tenant',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/mytenant'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== 基本信息卡片 =====
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant Information',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextField(
                        controller: _emailCtrl,
                        decoration: _inputDecoration('Tenant Email', icon: Icons.email),
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.montserrat(),
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      TextField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration('Full Name', icon: Icons.person),
                        style: GoogleFonts.montserrat(),
                      ),
                      const SizedBox(height: 16),

                      // Contact (password)
                      TextField(
                        controller: _contactCtrl,
                        decoration: _inputDecoration(
                          'Contact Number (used as password)',
                          icon: Icons.phone,
                        ).copyWith(errorText: _contactError),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.montserrat(),
                      ),
                      const SizedBox(height: 16),

                      // Unit (read‐only)
                      TextField(
                        controller: _unitCtrl,
                        decoration: _inputDecoration('Unit Number', icon: Icons.home),
                        readOnly: true,
                        style: GoogleFonts.montserrat(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===== 租约信息卡片 =====
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_note, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Lease Period',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 开始日期选择
                      Text(
                        'Start Date',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, 
                                  color: Colors.grey[600], size: 20),
                              const SizedBox(width: 12),
                              Text(
                                dateFormat.format(_leaseStartDate),
                                style: GoogleFonts.montserrat(fontSize: 16),
                              ),
                              const Spacer(),
                              Icon(Icons.edit, color: Colors.grey[400], size: 18),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 租期选择
                      Text(
                        'Lease Duration',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._leaseOptions.map((months) => ChoiceChip(
                            label: Text('$months months'),
                            labelStyle: GoogleFonts.montserrat(
                              color: _selectedLeaseMonths == months && !_useCustomMonths
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            selected: _selectedLeaseMonths == months && !_useCustomMonths,
                            selectedColor: Colors.red.shade700,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedLeaseMonths = months;
                                  _useCustomMonths = false;
                                });
                              }
                            },
                          )),
                          ChoiceChip(
                            label: const Text('Custom'),
                            labelStyle: GoogleFonts.montserrat(
                              color: _useCustomMonths ? Colors.white : Colors.black87,
                            ),
                            selected: _useCustomMonths,
                            selectedColor: Colors.red.shade700,
                            onSelected: (selected) {
                              setState(() => _useCustomMonths = selected);
                            },
                          ),
                        ],
                      ),

                      // 自定义月数输入
                      if (_useCustomMonths) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _customMonthsCtrl,
                            decoration: InputDecoration(
                              labelText: 'Months',
                              suffixText: 'months',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: GoogleFonts.montserrat(),
                            onChanged: (value) {
                              final months = int.tryParse(value);
                              if (months != null && months > 0) {
                                setState(() => _selectedLeaseMonths = months);
                              }
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // 结束日期显示
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_available, 
                                color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Date',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  dateFormat.format(_leaseEndDate),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 月租金（可选）
                      TextField(
                        controller: _rentCtrl,
                        decoration: _inputDecoration(
                          'Monthly Rent (optional)',
                          icon: Icons.attach_money,
                        ).copyWith(
                          prefixText: 'RM ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.montserrat(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit 按钮
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: _isLoading 
                      ? const SizedBox.shrink() 
                      : const Icon(Icons.person_add),
                  label: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Register Tenant',
                          style: GoogleFonts.montserrat(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                  onPressed: _isLoading ? null : _registerTenant,
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
