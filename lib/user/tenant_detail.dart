// lib/user/tenant_detail.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vanguardfyp/services/lease_service.dart';

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
  
  // 租约服务
  final LeaseService _leaseService = LeaseService();
  LeaseInfo? _leaseInfo;
  bool _isLoading = false;

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
      createdStr = DateFormat('dd MMM yyyy').format(dt);
    }
    
    // 获取租约信息
    _leaseInfo = data['leaseInfo'] as LeaseInfo?;
    if (_leaseInfo == null) {
      _loadLeaseInfo();
    }
  }

  Future<void> _loadLeaseInfo() async {
    if (tenantId.isEmpty) return;
    final info = await _leaseService.getLeaseInfo(tenantId);
    if (mounted) {
      setState(() => _leaseInfo = info);
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Remove Tenant', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to remove $fullName?\n\nThis will deactivate their account.', 
            style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.montserrat()),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Remove', style: GoogleFonts.montserrat(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
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
        title: Text('Edit Tenant', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              decoration: InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.montserrat()),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Save', style: GoogleFonts.montserrat(color: Colors.red.shade700)),
            onPressed: () => Navigator.pop(context, true),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant info updated')),
      );
    }
  }

  /// 显示续约对话框
  Future<void> _showExtendLeaseDialog() async {
    int selectedMonths = 12;
    final rentCtrl = TextEditingController(
      text: _leaseInfo?.monthlyRent?.toStringAsFixed(0) ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentEndDate = _leaseInfo?.endDate ?? DateTime.now();
          final baseDate = currentEndDate.isBefore(DateTime.now()) 
              ? DateTime.now() 
              : currentEndDate;
          final newEndDate = DateTime(
            baseDate.year,
            baseDate.month + selectedMonths,
            baseDate.day,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.event_repeat, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  _leaseInfo?.status == LeaseStatus.expired 
                      ? 'Renew Lease' 
                      : 'Extend Lease',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前结束日期
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current End Date',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _leaseInfo?.endDate != null
                                  ? DateFormat('dd MMM yyyy').format(_leaseInfo!.endDate!)
                                  : 'Not set',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    'Extend by:',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 月数选择
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [6, 12, 24].map((months) {
                      final isSelected = selectedMonths == months;
                      return ChoiceChip(
                        label: Text('$months months'),
                        labelStyle: GoogleFonts.montserrat(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        selected: isSelected,
                        selectedColor: Colors.green.shade700,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedMonths = months);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 新结束日期预览
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
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New End Date',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(newEndDate),
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 新月租金（可选）
                  TextField(
                    controller: rentCtrl,
                    decoration: InputDecoration(
                      labelText: 'New Monthly Rent (optional)',
                      prefixText: 'RM ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel', style: GoogleFonts.montserrat()),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Confirm', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                onPressed: () {
                  Navigator.pop(context, {
                    'months': selectedMonths,
                    'rent': double.tryParse(rentCtrl.text.trim()),
                  });
                },
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      
      try {
        await _leaseService.extendLease(
          tenantId: tenantId,
          additionalMonths: result['months'] as int,
          newMonthlyRent: result['rent'] as double?,
        );
        
        // 重新加载租约信息
        await _loadLeaseInfo();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lease extended by ${result['months']} months'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 获取状态对应的颜色
  Color _getStatusColor(LeaseStatus status) {
    switch (status) {
      case LeaseStatus.active:
        return Colors.green;
      case LeaseStatus.expiringSoon:
        return Colors.orange;
      case LeaseStatus.expired:
        return Colors.red;
      case LeaseStatus.noLease:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final statusColor = _leaseInfo != null 
        ? _getStatusColor(_leaseInfo!.status) 
        : Colors.grey;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Tenant Details', 
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ===== Header Card =====
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: statusColor,
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName, 
                                    style: GoogleFonts.montserrat(
                                      fontSize: 20, 
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Unit $unit', 
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // 状态标签
                                  if (_leaseInfo != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12, 
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(26),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: statusColor.withAlpha(128),
                                        ),
                                      ),
                                      child: Text(
                                        _leaseInfo!.statusText,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // ===== Contact Info =====
                    _InfoTile(icon: Icons.phone, label: 'Contact', value: contact),
                    _InfoTile(icon: Icons.home, label: 'Unit', value: unit),
                    _InfoTile(icon: Icons.calendar_today, label: 'Joined', value: createdStr),

                    const SizedBox(height: 16),

                    // ===== Lease Information Card =====
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.description, 
                                    color: Colors.red.shade700, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Lease Information',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            
                            if (_leaseInfo != null && _leaseInfo!.startDate != null) ...[
                              _LeaseInfoRow(
                                label: 'Start Date',
                                value: dateFormat.format(_leaseInfo!.startDate!),
                                icon: Icons.play_arrow,
                              ),
                              const SizedBox(height: 12),
                              _LeaseInfoRow(
                                label: 'End Date',
                                value: dateFormat.format(_leaseInfo!.endDate!),
                                icon: Icons.stop,
                                valueColor: statusColor,
                              ),
                              const SizedBox(height: 12),
                              _LeaseInfoRow(
                                label: 'Duration',
                                value: '${_leaseInfo!.leaseMonths ?? "-"} months',
                                icon: Icons.schedule,
                              ),
                              if (_leaseInfo!.monthlyRent != null) ...[
                                const SizedBox(height: 12),
                                _LeaseInfoRow(
                                  label: 'Monthly Rent',
                                  value: 'RM ${_leaseInfo!.monthlyRent!.toStringAsFixed(0)}',
                                  icon: Icons.attach_money,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _LeaseInfoRow(
                                label: 'Days Left',
                                value: _leaseInfo!.daysLeftText,
                                icon: Icons.timelapse,
                                valueColor: statusColor,
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // 进度条
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Lease Progress',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '${(_leaseInfo!.progress * 100).toStringAsFixed(0)}%',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _leaseInfo!.progress,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation(statusColor),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.event_busy, 
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No lease information set',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== Action Buttons =====
                    
                    // 续约按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.event_repeat),
                        label: Text(
                          _leaseInfo?.status == LeaseStatus.expired 
                              ? 'Renew Lease' 
                              : 'Extend Lease',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showExtendLeaseDialog,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 编辑按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: Text('Edit Tenant Info', 
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _editTenant,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 移除按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        label: Text('Remove Tenant', 
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600, 
                              color: Colors.red,
                            )),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _confirmRemove,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
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
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.red.shade700, size: 20),
        ),
        title: Text(label, 
            style: GoogleFonts.montserrat(
              fontSize: 12, 
              color: Colors.grey[600],
            )),
        subtitle: Text(value, 
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _LeaseInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _LeaseInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
