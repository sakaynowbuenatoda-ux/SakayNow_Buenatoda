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
      expect(rules, contains('request.resource.data.is_verified == false'));
      expect(rules, contains('request.resource.data.is_active == false'));
      expect(rules, contains('request.resource.data.is_banned == false'));
      expect(rules, contains('request.resource.data.email_verified == false'));
      expect(
        rules,
        contains("request.resource.data.account_status == 'active'"),
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
      expect(
        rules,
        contains('allow update: if isValidDriverAvailabilityUpdate(userId);'),
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
          ".hasOnly(['email_verified', 'email_verified_at', 'updated_at'])",
        ),
      );
      expect(rules, contains('request.resource.data.email_verified == true'));
      expect(
        rules,
        contains('request.resource.data.email_verified_at == request.time'),
      );
      expect(
        rules,
        contains('allow update: if isValidEmailVerificationUpdate(userId);'),
      );
      expect(
        rules,
        contains(".hasAny(['email_verified', 'email_verified_at'])"),
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
    });

    test('gate live driver locations to driver-owned verified accounts', () {
      expect(rules, contains('match /driver_locations/{driverId}'));
      expect(rules, contains('allow create, update: if isSelf(driverId)'));
      expect(rules, contains('&& isDriverRole(signedInUser())'));
      expect(rules, contains('request.resource.data.driver_id == driverId'));
      expect(rules, contains('request.resource.data.is_available != true'));
      expect(rules, contains('|| isVerifiedDriver()'));
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
        contains('request.auth.uid in request.resource.data.participant_ids'),
      );
      expect(rules, contains('match /messages/{messageId}'));
      expect(
        rules,
        contains('request.resource.data.sender_id == request.auth.uid'),
      );
      expect(rules, contains('request.resource.data.text.size() <= 1000'));
      expect(rules, contains('canWriteConversation(parentConversation())'));
    });
  });
}
