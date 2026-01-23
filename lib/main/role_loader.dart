import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vanguardfyp/services/lease_service.dart';
import 'package:vanguardfyp/services/notification_service.dart';
import 'router.dart'; // for fetchUserRole

class RoleLoader extends StatefulWidget {
  const RoleLoader({Key? key}) : super(key: key);

  @override
  _RoleLoaderState createState() => _RoleLoaderState();
}

class _RoleLoaderState extends State<RoleLoader> {
  final LeaseService _leaseService = LeaseService();

  @override
  void initState() {
    super.initState();
    _routeByRole();
  }

  Future<void> _routeByRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { context.go('/login'); return; }

    // 保存 FCM Token 用于推送通知
    await NotificationService().saveTokenToFirestore(user.uid);

    final doc = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(user.uid)
        .get();

    final data   = doc.data()!;
    final role   = data['role']   as String;
    final status = data['status'] as String? ?? 'pending';

    // 检查账户是否被停用
    if (status == 'inactive') {
      context.go('/user/removed');
      return;
    }

    if (role == 'owner') {
      if (status == 'pending') {
        context.go('/user/pendingApproval');      // ← show a "pending" info screen
      } else if (status == 'rejected') {
        context.go('/user/reuploadProof');        // ← route back to profile to re-upload
      } else {
        context.go('/user');                      // ← fully approved
      }
    } else if (role == 'tenant') {
      // ===== 租户租约检查 =====
      // 检查并更新租约状态
      final leaseStatus = await _leaseService.checkAndUpdateLeaseStatus(user.uid);
      
      if (leaseStatus == LeaseStatus.expired) {
        // 租约已过期，跳转到过期页面
        context.go('/user/leaseExpired');
      } else {
        // 租约正常或即将过期，允许登录
        context.go('/user');
      }
    } else if (role == 'security') {
      context.go('/security');
    } else if (role == 'admin') {
      context.go('/admin');
    } else {
      await FirebaseAuth.instance.signOut();
      context.go('/login');
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
