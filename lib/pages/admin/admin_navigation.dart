import 'package:flutter/material.dart';

import 'active_drivers.dart';
import 'completed_trips.dart';
import 'registered_users.dart';
import 'student_accounts.dart';
import 'trips_in_motion.dart';
import 'admin_unverified_users_page.dart';
import 'admin_user_review_page.dart';
import '../profile/view_user_profile.dart';

class AdminNavigation {
  AdminNavigation._();

  static void openUnverifiedDrivers(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUnverifiedUsersPage(
          adminId: adminId,
          queueType: AdminUnverifiedQueueType.drivers,
        ),
      ),
    );
  }

  static void openUnverifiedPassengers(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUnverifiedUsersPage(
          adminId: adminId,
          queueType: AdminUnverifiedQueueType.passengers,
        ),
      ),
    );
  }

  static void openUserReview(
    BuildContext context, {
    required String adminId,
    required String userId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserReviewPage(userId: userId, adminId: adminId),
      ),
    );
  }

  static void openRegisteredUsers(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisteredUsersPage(adminId: adminId)),
    );
  }

  static void openActiveDrivers(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActiveDriversPage(adminId: adminId)),
    );
  }

  static void openStudentAccounts(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudentAccountsPage(adminId: adminId)),
    );
  }

  static void openCompletedTrips(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CompletedTripsPage()));
  }

  static void openTripsInMotion(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TripsInMotionPage()));
  }

  static void openUserProfile(
    BuildContext context, {
    required String adminId,
    required String userId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewUserProfilePage(adminId: adminId, userId: userId),
      ),
    );
  }
}
