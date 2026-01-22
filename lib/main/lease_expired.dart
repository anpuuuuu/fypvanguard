// lib/main/lease_expired.dart
// 租约过期页面 - 当租户租约过期时显示此页面

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vanguardfyp/services/lease_service.dart';

class LeaseExpiredPage extends StatefulWidget {
  const LeaseExpiredPage({Key? key}) : super(key: key);

  @override
  _LeaseExpiredPageState createState() => _LeaseExpiredPageState();
}

class _LeaseExpiredPageState extends State<LeaseExpiredPage> {
  final LeaseService _leaseService = LeaseService();
  
  String _tenantName = '';
  String _ownerName = '';
  String _ownerContact = '';
  DateTime? _leaseEndDate;
  int _daysExpired = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      // 获取租户信息
      final residentDoc = await FirebaseFirestore.instance
          .collection('residents')
          .doc(user.uid)
          .get();
      final residentData = residentDoc.data();
      
      if (residentData != null) {
        _tenantName = residentData['fullName'] as String? ?? 'Tenant';
        
        // 获取租约结束日期
        final endDateRaw = residentData['leaseEndDate'];
        if (endDateRaw is Timestamp) {
          _leaseEndDate = endDateRaw.toDate();
          _daysExpired = DateTime.now().difference(_leaseEndDate!).inDays;
        }
        
        // 获取业主信息
        final ownerId = residentData['ownerId'] as String?;
        if (ownerId != null) {
          final ownerInfo = await _leaseService.getOwnerInfo(ownerId);
          _ownerName = ownerInfo['fullName'] ?? 'Owner';
          _ownerContact = ownerInfo['contactNumber'] ?? '-';
        }
      }
    } catch (e) {
      debugPrint('Error loading info: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 警告图标
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.event_busy,
                          size: 72,
                          color: Colors.red.shade700,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 标题
                      Text(
                        'Lease Expired',
                        style: GoogleFonts.montserrat(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 问候
                      Text(
                        'Hello, $_tenantName',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 说明卡片
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 48,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your tenancy has expired',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              
                              // 过期日期
                              if (_leaseEndDate != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event, 
                                          color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Expired on ${dateFormat.format(_leaseEndDate!)}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_daysExpired days ago',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 20),
                              
                              Text(
                                'Please contact your landlord to renew your lease and regain access to the app.',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 业主联系信息
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Your Landlord',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _ownerName,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.phone,
                                      color: Colors.green.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Contact Number',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _ownerContact,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
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
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 返回登录按钮
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: Text(
                            'Back to Login',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _logout,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 提示文字
                      Text(
                        'Once your landlord renews your lease,\nyou will be able to log in again.',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
