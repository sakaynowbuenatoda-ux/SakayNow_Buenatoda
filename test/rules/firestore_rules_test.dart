import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  group('Firestore rules', () {
    test('keep signup writes locked to safe user fields', () {
      expect(rules, contains('function isValidSignup(userId)'));
      expect(rules, contains('allow create: if isValidSignup(userId);'));
      expect(
        rules,
        contains("request.resource.data.role in ['passenger', 'driver']"),
      );
      expect(
        rules,
        contains(
          "request.resource.data.passenger_type in ['regular', 'student', 'senior_citizen']",
        ),
      );
      expect(rules, contains('request.resource.data.is_verified == false'));
      expect(rules, contains('request.resource.data.is_active == false'));
      expect(rules, contains('request.resource.data.is_banned == false'));
      expect(rules, contains('request.resource.data.email_verified == false'));
      expect(
        rules,
        contains("request.resource.data.account_status == 'active'"),
      );
      expect(rules, contains("request.resource.data.vehicle_type is string"));
      expect(rules, contains("request.resource.data.tricycle_color is string"));
      expect(rules, contains("request.resource.data.plate_number is string"));
      expect(
        rules,
        contains('request.resource.data.drivers_license_expiry is timestamp'),
      );
      expect(
        rules,
        contains('request.resource.data.or_cr_expiry is timestamp'),
      );
      expect(
        rules,
        contains("request.resource.data.document_status == 'valid'"),
      );
    });

    test('allow only narrow self availability updates for drivers', () {
      expect(
        rules,
        contains('function isValidDriverAvailabilityUpdate(userId)'),
      );
      expect(rules, contains(".hasOnly(['is_active', 'updated_at'])"));
      expect(rules, contains('isDriverRole(resource.data)'));
      expect(rules, contains('request.resource.data.is_active is bool'));
      expect(rules, contains('isVerifiedUser(resource.data)'));
      expect(rules, contains('isUsableAccount(resource.data)'));
      expect(rules, contains('hasCurrentDriverDocuments(resource.data)'));
      expect(rules, contains('&& isValidDriverAvailabilityUpdate(userId);'));
    });

    test('allow only narrow owner renewal submissions', () {
      expect(
        rules,
        contains('function isValidDriverRenewalSubmission(userId)'),
      );
      expect(rules, contains('function driverRenewalSubmissionFields()'));
      expect(rules, contains("'renewal_document_type'"));
      expect(rules, contains("'renewal_document_url'"));
      expect(rules, contains("'renewal_document_path'"));
      expect(rules, contains("'renewal_expiry'"));
      expect(rules, contains("'renewal_submitted_at'"));
      expect(
        rules,
        contains("request.resource.data.renewal_status == 'pending_renewal'"),
      );
      expect(rules, contains('.hasOnly(driverRenewalSubmissionFields())'));
      expect(rules, contains('&& isValidDriverRenewalSubmission(userId);'));
    });

    test('stage owner credential additions and replacements for review', () {
      expect(rules, contains('function isValidDriverCredentialUpdate(userId)'));
      expect(rules, contains('function driverCredentialUpdateFields()'));
      expect(rules, contains('function isExistingCredentialDocument('));
      expect(rules, contains('function isUploadedCredentialDocument('));
      expect(rules, contains("pendingReview.kind == 'driver_credential'"));
      expect(rules, contains("'pending_document_review'"));
      expect(
        rules,
        contains("request.resource.data.document_upload_status == 'uploaded'"),
      );
      expect(
        rules,
        contains("request.resource.data.document_review_status == 'pending'"),
      );
      expect(rules, contains('request.resource.data.credential_updated_at'));
      expect(rules, contains('&& isValidDriverCredentialUpdate(userId)'));
    });

    test('stage passenger verification documents for review', () {
      expect(
        rules,
        contains('function isValidPassengerDocumentUpload(userId)'),
      );
      expect(rules, contains('function passengerDocumentUploadFields()'));
      expect(rules, contains("pendingReview.kind == 'passenger_identity'"));
      expect(rules, contains("'id_image_path'"));
      expect(rules, contains("'selfie_path'"));
      expect(rules, contains("'document_submitted_at'"));
      expect(rules, contains('isPassengerRole(resource.data)'));
      expect(rules, contains('isUsableAccount(resource.data)'));
      expect(
        rules,
        contains("pendingReview.keys().hasAny(['id_image_url', 'selfie_url'])"),
      );
      expect(
        rules,
        contains('request.resource.data.document_submitted_at == request.time'),
      );
      expect(rules, contains('&& isValidPassengerDocumentUpload(userId)'));
      expect(
        rules,
        contains('function hasNoProtectedPassengerDocumentChanges()'),
      );
    });

    test('keep renewal decisions and approved documents admin-controlled', () {
      expect(rules, contains('function driverDocumentAdminFields()'));
      expect(rules, contains('function hasNoProtectedDriverDocumentChanges()'));
      expect(rules, contains("'renewal_reviewed_at'"));
      expect(rules, contains("'renewal_reviewed_by'"));
      expect(rules, contains("'renewal_rejection_reason'"));
      expect(rules, contains('|| hasNoProtectedDriverDocumentChanges()'));
      expect(
        rules,
        contains(
          'allow update, delete: if isAdmin() && !isAdminRole(resource.data);',
        ),
      );
    });

    test('allow verified auth users to sync email verification status', () {
      expect(
        rules,
        contains('function isValidEmailVerificationUpdate(userId)'),
      );
      expect(rules, contains('request.auth.token.email_verified == true'));
      expect(
        rules,
        contains(
          ".hasOnly(['email', 'email_verified', 'email_verified_at', 'updated_at'])",
        ),
      );
      expect(rules, contains('request.auth.token.email is string'));
      expect(rules, contains('request.resource.data.email is string'));
      expect(
        rules,
        contains('request.resource.data.email == request.auth.token.email'),
      );
      expect(rules, contains('request.resource.data.email_verified == true'));
      expect(
        rules,
        contains('request.resource.data.email_verified_at == request.time'),
      );
      expect(rules, contains('&& isValidEmailVerificationUpdate(userId);'));
      expect(
        rules,
        contains(".hasAny(['email_verified', 'email_verified_at'])"),
      );
    });

    test('allow passengers to sync only quick destination fields', () {
      expect(
        rules,
        contains('function isValidQuickDestinationsUpdate(userId)'),
      );
      expect(
        rules,
        contains(
          "'quick_destinations',\n            'quick_destinations_updated_at'",
        ),
      );
      expect(
        rules,
        contains('request.resource.data.quick_destinations is list'),
      );
      expect(
        rules,
        contains('request.resource.data.quick_destinations.size() <= 20'),
      );
      expect(
        rules,
        contains(
          'request.resource.data.quick_destinations_updated_at == request.time',
        ),
      );
      expect(rules, contains('&& isValidQuickDestinationsUpdate(userId);'));
    });

    test('allow drivers to sync payout account metadata narrowly', () {
      expect(rules, contains('function isValidDriverPayoutSyncUpdate(userId)'));
      expect(rules, contains('function driverPayoutSyncAllowedKeys()'));
      expect(rules, contains("'accepts_online_payments'"));
      expect(rules, contains("'online_payment_methods'"));
      expect(rules, contains("'default_payout_account_id'"));
      expect(rules, contains('.hasOnly(driverPayoutSyncAllowedKeys())'));
      expect(
        rules,
        contains('request.resource.data.accepts_online_payments is bool'),
      );
      expect(
        rules,
        contains("paymentMethods.hasOnly(['gcash', 'maya', 'bank'])"),
      );
      expect(rules, contains('&& isValidDriverPayoutSyncUpdate(userId);'));
    });

    test('stage owner vehicle detail and photo updates for review', () {
      expect(rules, contains('function driverVehicleUpdateFields()'));
      expect(rules, contains('function isValidPendingVehicleImage('));
      expect(rules, contains('function isValidDriverVehicleUpdate(userId)'));
      expect(rules, contains("'tricycle_front_path'"));
      expect(rules, contains("'tricycle_back_path'"));
      expect(rules, contains("'/vehicle_photos/' + photoName + '_[^/]+'"));
      expect(
        rules,
        contains(
          'request.resource.data.vehicle_details_updated_at == request.time',
        ),
      );
      expect(rules, contains("pendingReview.kind == 'driver_vehicle'"));
      expect(
        rules,
        contains("request.resource.data.document_review_status == 'pending'"),
      );
      expect(rules, contains('&& isValidDriverVehicleUpdate(userId)'));
    });

    test('allow unverified drivers to recover missing hub documents', () {
      expect(
        rules,
        contains('function isValidUnverifiedDriverCredentialUpdate(userId)'),
      );
      expect(
        rules,
        contains('function isValidUnverifiedDriverVehicleUpdate(userId)'),
      );
      expect(
        rules,
        contains('&& isValidUnverifiedDriverCredentialUpdate(userId);'),
      );
      expect(
        rules,
        contains('&& isValidUnverifiedDriverVehicleUpdate(userId);'),
      );
      expect(rules, contains('&& !isVerifiedUser(resource.data)'));
    });

    test('allow driver-owned payout account default toggles', () {
      expect(rules, contains('match /payout_accounts/{accountId}'));
      expect(rules, contains('function isValidPayoutDefaultToggle(userId)'));
      expect(rules, contains('function isOwnedDriverPayoutAccount'));
      expect(rules, contains(".hasOnly(['is_default', 'updated_at'])"));
      expect(rules, contains('request.resource.data.is_default is bool'));
      expect(
        rules,
        contains('allow update: if isValidPayoutDefaultToggle(userId);'),
      );
    });

    test('tolerate legacy user records in driver gates', () {
      expect(rules, contains("function userRole(userData)"));
      expect(rules, contains("userData.get('role', '')"));
      expect(rules, contains("userData.get('is_verified', false) == true"));
      expect(rules, contains("userData.get('isVerified', false) == true"));
      expect(rules, contains("userData.get('isVerrified', false) == true"));
      expect(rules, contains("userData.get('is_banned', false) != true"));
      expect(
        rules,
        contains("userData.get('account_status', 'active') != 'deactivated'"),
      );
      expect(
        rules,
        contains('function isValidVerificationCanonicalization(affectedKeys)'),
      );
      expect(rules, contains('request.resource.data.is_verified == true'));
    });

    test('gate live driver locations to driver-owned verified accounts', () {
      expect(rules, contains('match /driver_locations/{driverId}'));
      expect(rules, contains('allow create, update: if isSelf(driverId)'));
      expect(rules, contains('&& isDriverRole(signedInUser())'));
      expect(rules, contains('request.resource.data.driver_id == driverId'));
      expect(rules, contains('request.resource.data.is_available != true'));
      expect(rules, contains('|| isVerifiedDriver()'));
      expect(rules, contains('&& hasCurrentDriverDocuments(signedInUser())'));
    });

    test('allow top driver leaderboard queries through canonical fields', () {
      expect(
        rules,
        contains('function isCanonicalLeaderboardDriverProfile(userData)'),
      );
      expect(rules, contains("userData.role == 'driver'"));
      expect(rules, contains('userData.is_verified == true'));
      expect(rules, contains('userData.is_banned == false'));
      expect(
        rules,
        contains('&& isCanonicalLeaderboardDriverProfile(resource.data)'),
      );
    });

    test('protect bookings and ride messages by user role and membership', () {
      expect(rules, contains('match /bookings/{bookingId}'));
      expect(rules, contains('function canReadBooking(bookingData)'));
      expect(rules, contains('allow read: if canReadBooking(resource.data);'));
      expect(
        rules,
        contains(
          "bookingData.status in ['searching', 'pending', 'queued', 'new']",
        ),
      );
      expect(
        rules,
        contains('request.resource.data.passenger_id == request.auth.uid'),
      );
      expect(rules, contains('|| isVerifiedDriver()'));
      expect(rules, contains('bookingData.passenger_id == request.auth.uid'));
      expect(rules, contains('bookingData.driver_id == request.auth.uid'));
      expect(
        rules,
        isNot(contains("bookingData.keys().hasAny(['passenger_id'])")),
      );
      expect(
        rules,
        isNot(contains("bookingData.keys().hasAny(['driver_id'])")),
      );

      expect(rules, contains('match /conversations/{conversationId}'));
      expect(
        rules,
        contains('function isUserVisibleConversation(conversationData)'),
      );
      expect(rules, contains("conversationData.type in ['ride', 'support']"));
      expect(rules, contains('&& isUserVisibleConversation(conversationData)'));
      expect(rules, contains("request.resource.data.type == 'support'"));
      expect(rules, contains('function isRideConversation(conversationData)'));
      expect(
        rules,
        contains(
          'request.resource.data.passenger_id == conversationData.passenger_id',
        ),
      );
      expect(
        rules,
        contains(
          "request.resource.data.get('booking_ids', [])\n              == conversationData.get('booking_ids', [])",
        ),
      );
      expect(
        rules,
        contains('function isAdminCreatedSupportConversation(conversationId)'),
      );
      expect(
        rules,
        contains(
          "conversationId == 'support_' + request.resource.data.support_user_id",
        ),
      );
      expect(rules, contains('match /messages/{messageId}'));
      expect(
        rules,
        contains('request.resource.data.sender_id == request.auth.uid'),
      );
      expect(rules, contains('request.resource.data.text.size() <= 1000'));
      expect(rules, contains('canWriteConversation(parentConversation())'));
    });

    test('restrict ETA writes to the assigned verified driver path', () {
      expect(rules, contains('function hasNoEtaChanges()'));
      expect(rules, contains('function isValidDriverEtaUpdate()'));
      expect(rules, contains('resource.data.driver_id == request.auth.uid'));
      expect(
        rules,
        contains(
          "resource.data.status in ['accepted', 'driver_arriving', 'arrived']",
        ),
      );
      expect(rules, contains("resource.data.status == 'in_progress'"));
      expect(rules, contains(".hasAny(['eta'])"));
      expect(rules, contains('allow update: if isValidDriverEtaUpdate();'));
    });

    test('protect commission settings and driver earnings visibility', () {
      expect(rules, contains("'regular_passenger_discount_rate'"));
      expect(rules, contains("'senior_citizen_discount_rate'"));
      expect(rules, contains("'driver_pickup_surcharge_per_extra_barangay'"));
      expect(rules, contains("'max_driver_pickup_surcharge'"));
      expect(rules, contains('settingsData.senior_citizen_discount_rate <= 1'));
      expect(
        rules,
        contains(
          'settingsData.max_driver_pickup_surcharge >= settingsData.driver_pickup_surcharge_per_extra_barangay',
        ),
      );
      expect(rules, contains("'commission_rate'"));
      expect(rules, contains('settingsData.commission_rate is number'));
      expect(rules, contains('settingsData.commission_rate >= 0'));
      expect(rules, contains('settingsData.commission_rate <= 1'));
      expect(
        rules,
        contains("allow create, update: if settingId == 'current'"),
      );
      expect(rules, contains('&& isAdmin()'));
      expect(rules, contains('bookingData.driver_id == request.auth.uid'));
    });

    test('keep platform commission checkout account admin-only', () {
      expect(
        rules,
        contains('match /platform_commission_accounts/{accountId}'),
      );
      expect(
        rules,
        contains("allow read: if accountId == 'current' && isAdmin();"),
      );
      expect(
        rules,
        contains('function isValidPlatformCommissionAccount(accountData)'),
      );
      expect(rules, contains("accountData.provider == 'xendit'"));
      expect(rules, contains('accountData.updated_by == request.auth.uid'));
      expect(rules, contains('allow delete: if false;'));
    });

    test('keep notification documents server-created and owner-readable', () {
      expect(rules, contains('match /notifications/{notificationId}'));
      expect(
        rules,
        contains(
          'allow read: if isAdmin()\n        || (signedIn() && resource.data.user_id == request.auth.uid);',
        ),
      );
      expect(rules, contains('allow create: if false;'));
      expect(
        rules,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly([\n          'is_read',\n          'read_at'",
        ),
      );
      expect(rules, contains('allow update, delete: if isAdmin();'));
    });

    test('keep login history immutable and visible only to its owner', () {
      expect(rules, contains('match /login_activity/{activityId}'));
      expect(rules, contains('allow read: if isSelf(userId);'));
      expect(
        rules,
        contains('request.resource.data.signed_in_at == request.time'),
      );
      expect(rules, contains('request.resource.data.user_id == userId'));
      expect(
        rules,
        contains("request.resource.data.auth_method == 'password'"),
      );
      expect(rules, contains('allow update, delete: if false;'));
    });

    test('allow report duplicate checks without opening report reads', () {
      expect(rules, contains('function isMissingDailyReportProbe(reportId)'));
      expect(
        rules,
        contains(
          r"reportId.matches('^daily_[0-9]{8}_[A-Za-z0-9_-]+_[A-Za-z0-9_-]+$')",
        ),
      );
      expect(rules, contains('&& !exists(reportDocumentPath(reportId))'));
      expect(
        rules,
        contains('allow get: if isMissingDailyReportProbe(reportId);'),
      );
      expect(
        rules,
        contains(
          '|| (signedIn() && resource.data.reporter_id == request.auth.uid)',
        ),
      );
      expect(
        rules,
        contains(
          '|| (signedIn() && resource.data.reported_user_id == request.auth.uid)',
        ),
      );
      expect(rules, contains('allow update, delete: if isAdmin();'));
    });

    test('require active usable admin accounts for admin privileges', () {
      expect(rules, contains('function isActiveAccount(userData)'));
      expect(rules, contains("userData.get('is_active', true) == true"));
      expect(rules, contains('&& isActiveAccount(signedInUser())'));
      expect(rules, contains('function isRegularAdminRole(userData)'));
      expect(rules, contains('function isSuperAdminRole(userData)'));
      expect(rules, contains('function isSuperAdmin()'));
      expect(rules, contains("'super_admin'"));
    });

    test('protect admin user documents from client-side mutation', () {
      expect(
        rules,
        contains(
          'allow update, delete: if isAdmin() && !isAdminRole(resource.data);',
        ),
      );
      expect(rules, contains('allow update: if !isAdminRole(resource.data)'));
    });

    test('keeps admin direct creation server-owned and participant-scoped', () {
      expect(
        rules,
        contains('function isAdminDirectConversation(conversationData)'),
      );
      expect(rules, contains("request.resource.data.type == 'support'"));
      expect(rules, isNot(contains('isAdminCreatedAdminDirectConversation')));
      expect(
        rules,
        contains('&& request.auth.uid in conversationData.participant_ids'),
      );
      expect(
        rules,
        contains(
          'request.resource.data.participant_names == conversationData.participant_names',
        ),
      );
      expect(
        rules,
        contains(
          'request.resource.data.participant_roles == conversationData.participant_roles',
        ),
      );
    });
  });
}
