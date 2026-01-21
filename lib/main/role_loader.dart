import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'router.dart'; // for fetchUserRole

class RoleLoader extends StatefulWidget {
  const RoleLoader({Key? key}) : super(key: key);

  @override
  _RoleLoaderState createState() => _RoleLoaderState();
}

class _RoleLoaderState extends State<RoleLoader> {
  @override
  void initState() {
    super.initState();
    _routeByRole();
  }

  Future<void> _routeByRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { context.go('/login'); return; }

    final doc = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(user.uid)
        .get();

    final data   = doc.data()!;
    final role   = data['role']   as String;
    final status = data['status'] as String? ?? 'pending';

    if (status == 'inactive') {
      context.go('/user/removed');
      return;
    }

    if (role == 'owner') {
      if (status == 'pending') {
        context.go('/user/pendingApproval');      // ← show a “pending” info screen
      } else if (status == 'rejected') {
        context.go('/user/reuploadProof');        // ← route back to profile to re-upload
      } else {
        context.go('/user');                      // ← fully approved
      }
    } else if (role == 'tenant') {
      context.go('/user');
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