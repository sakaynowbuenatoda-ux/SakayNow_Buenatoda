import 'package:flutter/material.dart';

import 'admin_models.dart';
import 'active_drivers.dart';
import 'admin_accounts_page.dart';
import 'admin_booking_history_page.dart';
import 'admin_deactivated_users_page.dart';
import 'admin_document_reviews_page.dart';
import 'admin_expired_driver_documents_page.dart';
import 'admin_restricted_users_page.dart';
import 'admin_report_details_page.dart';
import 'registered_users.dart';
import 'student_accounts.dart';
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

  static void openDocumentReviews(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDocumentReviewsPage(adminId: adminId),
      ),
    );
  }

  static void openDeactivatedUsers(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDeactivatedUsersPage(adminId: adminId),
      ),
    );
  }

  static void openRestrictedUsers(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminRestrictedUsersPage(adminId: adminId),
      ),
    );
  }

  static void openAdminAccounts(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminAccountsPage(adminId: adminId)),
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

  static void openExpiredDriverDocuments(
    BuildContext context, {
    required String adminId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminExpiredDriverDocumentsPage(adminId: adminId),
      ),
    );
  }

  static void openBookingHistory(
    BuildContext context, {
    AdminBookingHistorySection initialSection = AdminBookingHistorySection.all,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminBookingHistoryPage(initialSection: initialSection),
      ),
    );
  }

  static void openCompletedTrips(BuildContext context) {
    openBookingHistory(
      context,
      initialSection: AdminBookingHistorySection.completed,
    );
  }

  static void openTripsInMotion(BuildContext context) {
    openBookingHistory(
      context,
      initialSection: AdminBookingHistorySection.ongoing,
    );
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

  static void openReportDetails(
    BuildContext context, {
    required String adminId,
    required AdminReportRecord report,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdminReportDetailsPage(adminId: adminId, report: report),
      ),
    );
  }
}
