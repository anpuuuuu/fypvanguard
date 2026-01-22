// lib/user/my_tenant.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vanguardfyp/user/tenant_detail.dart';
import 'package:vanguardfyp/services/lease_service.dart';
import 'RegisterVisitorForm.dart';

class MyTenantPage extends StatefulWidget {
  const MyTenantPage({Key? key}) : super(key: key);

  @override
  _MyTenantPageState createState() => _MyTenantPageState();
}

class _MyTenantPageState extends State<MyTenantPage> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  final LeaseService _leaseService = LeaseService();
  
  // 过期统计
  int _expiringSoonCount = 0;
  int _expiredCount = 0;

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
      int expiringSoon = 0;
      int expired = 0;

      for (final doc in tenantsSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['residentId'] = doc.id;

        // Load their account data
        final acctSnap = await FirebaseFirestore.instance
            .collection('accounts')
            .doc(doc.id)
            .get();
        final acct = acctSnap.data() ?? {};
        final role = acct['role'] as String? ?? '';

        // Only tenants
        if (role == 'tenant') {
          // 获取租约信息并检查状态
          final leaseInfo = LeaseInfo.fromMap(data);
          
          // 更新账户状态
          await _leaseService.checkAndUpdateLeaseStatus(doc.id);
          
          // 重新获取更新后的状态
          final updatedAcctSnap = await FirebaseFirestore.instance
              .collection('accounts')
              .doc(doc.id)
              .get();
          final updatedStatus = updatedAcctSnap.data()?['status'] as String? ?? 'inactive';
          
          data['status'] = updatedStatus;
          data['leaseInfo'] = leaseInfo;
          
          // 统计
          if (leaseInfo.status == LeaseStatus.expiringSoon) {
            expiringSoon++;
          } else if (leaseInfo.status == LeaseStatus.expired) {
            expired++;
          }
          
          tenants.add(data);
        }
      }

      // 按状态排序：过期 > 即将过期 > 正常
      tenants.sort((a, b) {
        final aInfo = a['leaseInfo'] as LeaseInfo;
        final bInfo = b['leaseInfo'] as LeaseInfo;
        return bInfo.status.index.compareTo(aInfo.status.index);
      });

      setState(() {
        _tenants = tenants;
        _expiringSoonCount = expiringSoon;
        _expiredCount = expired;
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

  /// 获取状态对应的图标
  IconData _getStatusIcon(LeaseStatus status) {
    switch (status) {
      case LeaseStatus.active:
        return Icons.check_circle;
      case LeaseStatus.expiringSoon:
        return Icons.warning;
      case LeaseStatus.expired:
        return Icons.cancel;
      case LeaseStatus.noLease:
        return Icons.help_outline;
    }
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
        title: Text('My Tenants', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.red.shade700))
          : Column(
              children: [
                // ===== 警告横幅 =====
                if (_expiringSoonCount > 0 || _expiredCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: _expiredCount > 0 
                        ? Colors.red.shade50 
                        : Colors.orange.shade50,
                    child: Row(
                      children: [
                        Icon(
                          _expiredCount > 0 ? Icons.error : Icons.warning,
                          color: _expiredCount > 0 ? Colors.red : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _expiredCount > 0
                                ? '$_expiredCount tenant(s) expired${_expiringSoonCount > 0 ? ", $_expiringSoonCount expiring soon" : ""}'
                                : '$_expiringSoonCount tenant(s) expiring soon',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: _expiredCount > 0 
                                  ? Colors.red.shade700 
                                  : Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // ===== 租户列表 =====
                Expanded(
                  child: _tenants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, 
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('You have no tenants.',
                                  style: GoogleFonts.montserrat(color: Colors.grey)),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text('Register Tenant', 
                                    style: GoogleFonts.montserrat()),
                                onPressed: () => GoRouter.of(context).go('/tenantregister'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTenants,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _tenants.length,
                            itemBuilder: (context, i) {
                              final tenant = _tenants[i];
                              final fullName = (tenant['fullName'] as String?) ?? '';
                              final unit = (tenant['unitNumber'] as String?) ?? '-';
                              final status = (tenant['status'] as String?) ?? 'inactive';
                              final leaseInfo = tenant['leaseInfo'] as LeaseInfo;
                              
                              final statusColor = _getStatusColor(leaseInfo.status);
                              final statusIcon = _getStatusIcon(leaseInfo.status);
                              final isAccessible = status != 'inactive';

                              // Avatar initial
                              final initial = fullName.isNotEmpty
                                  ? fullName[0].toUpperCase()
                                  : '?';

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: leaseInfo.status == LeaseStatus.expired
                                      ? BorderSide(color: Colors.red.shade300, width: 1.5)
                                      : leaseInfo.status == LeaseStatus.expiringSoon
                                          ? BorderSide(color: Colors.orange.shade300, width: 1.5)
                                          : BorderSide.none,
                                ),
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: InkWell(
                                  onTap: isAccessible
                                      ? () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TenantDetailPage(tenant: tenant),
                                            ),
                                          );
                                          // 返回时刷新列表
                                          _loadTenants();
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 顶部行：头像 + 姓名 + 状态
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: statusColor,
                                              radius: 24,
                                              child: Text(
                                                initial, 
                                                style: const TextStyle(
                                                  color: Colors.white, 
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fullName.isNotEmpty ? fullName : 'No Name',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 16, 
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Unit $unit',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 状态标签
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10, 
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withAlpha(26),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: statusColor.withAlpha(128),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(statusIcon, 
                                                      size: 14, color: statusColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    leaseInfo.statusText,
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),
                                        
                                        // 租约信息行
                                        Row(
                                          children: [
                                            Icon(Icons.event, 
                                                size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            if (leaseInfo.endDate != null) ...[
                                              Text(
                                                'Expires: ${dateFormat.format(leaseInfo.endDate!)}',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${leaseInfo.daysLeftText})',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ] else ...[
                                              Text(
                                                'No lease date set',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            if (isAccessible)
                                              Icon(Icons.arrow_forward_ios, 
                                                  size: 14, color: Colors.grey[400]),
                                          ],
                                        ),
                                        
                                        // 续约按钮（仅在即将过期或已过期时显示）
                                        if (leaseInfo.status == LeaseStatus.expiringSoon ||
                                            leaseInfo.status == LeaseStatus.expired) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.green.shade700,
                                                side: BorderSide(color: Colors.green.shade700),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(Icons.refresh, size: 18),
                                              label: Text(
                                                leaseInfo.status == LeaseStatus.expired 
                                                    ? 'Renew Lease' 
                                                    : 'Extend Lease',
                                                style: GoogleFonts.montserrat(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              onPressed: () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => TenantDetailPage(tenant: tenant),
                                                  ),
                                                );
                                                _loadTenants();
                                              },
                                            ),
                                          ),
                                        ],
                                        
                                        // 停用状态的重新激活按钮
                                        if (status == 'inactive') ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.blue.shade700,
                                                side: BorderSide(color: Colors.blue.shade700),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(Icons.restore, size: 18),
                                              label: Text(
                                                'Reactivate Account',
                                                style: GoogleFonts.montserrat(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              onPressed: () => _reactivateTenant(
                                                  tenant['residentId'] as String),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),

      // ─── "Register Tenant" FAB ─────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade700,
        onPressed: () => GoRouter.of(context).go('/tenantregister'),
        icon: const Icon(Icons.person_add),
        label: Text('Add Tenant', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
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
