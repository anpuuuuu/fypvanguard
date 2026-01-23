import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vanguardfyp/main/pending_approval.dart';
import 'package:vanguardfyp/main/register_page.dart';
import 'package:vanguardfyp/main/reupload_proof.dart';
import 'package:vanguardfyp/main/role_loader.dart';
import 'package:vanguardfyp/main/lease_expired.dart';

// user screens
import '../admin/admin_feedback_inbox.dart';
import '../admin/emergency_contacts.dart';
import '../admin/facility_management.dart';
import '../security/emergency_alerts.dart';
import '../security/feedback_inbox.dart';
import '../security/security_chat.dart';
import '../security/security_chat_page.dart';
import '../user/comments_page.dart';
import '../user/emergency_page.dart';
import '../user/feedback_page.dart';
import '../user/group_chat.dart';
import '../user/my_tenant.dart';
import '../user/tenantRegister.dart';
import '../user/user_chat_page.dart';
import '../user/user_home.dart';
import '../user/facility_booking.dart';
import '../user/maintenance_request.dart';
import '../user/RegisterVisitorForm.dart';

// admin screens
import '../admin/admin_home.dart';
import '../admin/owner_approvals.dart';
import '../admin/user_management.dart';
import '../admin/analytics.dart';
import '../admin/announcements.dart';

// security screens
import '../security/security_home.dart';
import '../security/visitor_approval.dart';
import '../security/booking_approval.dart';
import '../security/maintenance_review.dart';
import '../security/visitor_tracking.dart';
import '../user/user_profile.dart';
import 'account_removed.dart';
import 'login_screen.dart';

// Helper for auth stream
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

Future<String> fetchUserRole(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('accounts').doc(uid).get();
  return doc.data()?['role'] as String? ?? 'tenant';
}

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final currentPath = state.location;

    // Allow access to these routes without authentication
    final publicRoutes = ['/login', '/register'];

    if (user == null) {
      return publicRoutes.contains(currentPath)
          ? null // Stay on public routes
          : '/login'; // Redirect others to login
    } else {
      // If logged in, block access to login/register
      if (publicRoutes.contains(currentPath)) {
        return '/loading'; // Redirect to role loader
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: '/user/removed', builder: (c, s) => const AccountRemovedPage()),
    GoRoute(path: '/user/leaseExpired', builder: (c, s) => const LeaseExpiredPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/loading', builder: (context, state) => const RoleLoader()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const OwnerRegisterScreen(),
    ),
    GoRoute(
      path: '/user/pendingApproval',
      builder: (c, s) => const PendingApprovalPage(),
    ),
    GoRoute(
      path: '/user/reuploadProof',
      builder: (c, s) => const ReuploadProofPage(),
    ),
    GoRoute(
      path: '/userprofile',
      builder: (context, state) => const UserProfilePage(),
    ),
    // User routes
    GoRoute(path: '/user', builder: (context, state) => const UserHome()),
    GoRoute(path: '/user/bookFacility', builder: (context, state) => const FacilityBookingPage()),
    GoRoute(path: '/user/maintenanceRequest', builder: (context, state) => const MaintenanceRequestPage()),
    GoRoute(path: '/mytenant', builder: (context, state) => const MyTenantPage()),
    GoRoute(path: '/tenantregister', builder: (context, state) => const TenantRegisterPage()),
    GoRoute(
      path: '/user/feedback',
      builder: (context, state) => const FeedbackPage(),
    ),
    GoRoute(
      path: '/user/emergency',
      builder: (context, state) => const EmergencyPage(),
    ),
    GoRoute(
      path: '/user/registerVisitor',
      builder: (context, state) => const RegisterVisitorForm(entryType: 'walk-in'),
    ),
    GoRoute(
      path: '/user/chat',
      builder: (context, state) => const UserChatPage(),
    ),
    GoRoute(
      path: '/groupChat',
      builder: (context, state) => const GroupChatPage(),
    ),
    GoRoute(
      path: '/groupChat/comments/:postId',
      builder: (context, state) {
        final postId = state.params['postId']!;
        return CommentsPage(postId: postId);
      },
    ),
    // Admin routes
    GoRoute(path: '/admin', builder: (context, state) => const AdminHome()),
    GoRoute(path: '/admin/ownerApprovals', builder: (context, state) => const OwnerApprovalsPage()),
    GoRoute(path: '/admin/userManagement', builder: (context, state) => const UserManagementPage()),
    GoRoute(path: '/admin/analytics', builder: (context, state) => const AnalyticsPage()),
    GoRoute(
      path: '/admin/announcements',
      builder: (context, state) => const AdminAnnouncementsPage(),
    ),
    GoRoute(
      path: '/admin/facilities',
      builder: (context, state) => const FacilityManagementPage(),
    ),
    GoRoute(
      path: '/admin/emergencyContact',
      builder: (context, state) => const EmergencyContactsPage(),
    ),
    GoRoute(
      path: '/admin/feedback',
      builder: (context, state) => const AdminFeedbackInboxPage(),
    ),

    // Security routes
    GoRoute(path: '/security', builder: (context, state) => const SecurityHome()),
    GoRoute(path: '/security/visitorApproval', builder: (context, state) => const VisitorApprovalPage()),
    GoRoute(path: '/security/visitorTracking', builder: (context, state) => const VisitorTrackingPage()),
    GoRoute(path: '/security/bookingApproval', builder: (context, state) => const BookingApprovalPage()),
    GoRoute(path: '/security/maintenanceReview', builder: (context, state) => const MaintenanceReviewPage()),
    GoRoute(
      path: '/security/feedback',
      builder: (context, state) => const FeedbackInboxPage(),
    ),
    GoRoute(
      path: '/security/chat/:residentId',
      builder: (context, state) {
        final residentId = state.params['residentId']!;
        return SecurityChatPage(residentId: residentId);
      },
    ),
    GoRoute(
      path: '/security/emergencyAlerts',
      builder: (context, state) => const EmergencyAlertsPage(),
    ),
    GoRoute(
      path: '/security/chat',
      builder: (context, state) => const SecurityChatListPage(),
    ),
  ],
);