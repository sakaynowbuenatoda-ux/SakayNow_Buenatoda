import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/session/app_user.dart';
import 'package:sakaynow_buenatoda/pages/profile/models/profile_view_data.dart';
import 'package:sakaynow_buenatoda/services/profile_picture_service.dart';

void main() {
  group('AppUser.fromMap', () {
    test(
      'normalizes legacy passenger roles into passenger + passenger_type',
      () {
        final user = AppUser.fromMap(<String, dynamic>{
          'user_id': 'user-1',
          'first_name': 'Ana',
          'last_name': 'Santos',
          'email': 'ana@example.com',
          'role': 'student',
          'isVerified': true,
          'isActive': true,
          'isBanned': false,
        }, 'fallback-id');

        expect(user.userId, 'fallback-id');
        expect(user.role, 'passenger');
        expect(user.passengerType, 'student');
        expect(user.userRole, UserRole.passenger);
        expect(user.roleLabel, 'Student Passenger');
        expect(user.accessState(), AccountAccessState.active);
      },
    );

    test('allows approved users to continue even if email is not verified', () {
      final user = AppUser.fromMap(<String, dynamic>{
        'user_id': 'driver-1',
        'first_name': 'Juan',
        'last_name': 'Dela Cruz',
        'email': 'juan@example.com',
        'role': 'driver',
        'isVerified': true,
        'isActive': true,
        'isBanned': false,
      }, 'fallback-id');

      expect(user.accessState(), AccountAccessState.active);
    });

    test('recognizes deactivated and deleted account states', () {
      final deactivated = AppUser.fromMap(<String, dynamic>{
        'role': 'passenger',
        'account_status': 'deactivated',
      }, 'user-1');
      final deleted = AppUser.fromMap(<String, dynamic>{
        'role': 'driver',
        'account_status': 'deleted',
      }, 'user-2');

      expect(deactivated.isDeactivated, isTrue);
      expect(deactivated.accessState(), AccountAccessState.deactivated);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.accessState(), AccountAccessState.deleted);
    });

    test('uses profile picture before signup selfie', () {
      final user = AppUser.fromMap(<String, dynamic>{
        'role': 'passenger',
        'profile_picture_url': 'profile-picture-url',
        'selfie_url': 'selfie-url',
      }, 'user-1');

      expect(user.profileImageUrl, 'profile-picture-url');
    });
  });

  group('ProfileViewData avatar precedence', () {
    test('uses profile picture, then selfie, then initials', () {
      final withProfilePicture = ProfileViewData.fromMap(<String, dynamic>{
        'first_name': 'Ana',
        'last_name': 'Santos',
        'role': 'passenger',
        'profile_picture_url': 'profile-picture-url',
        'selfie_url': 'selfie-url',
        'id_image_url': 'id-url',
      }, 'user-1');
      final withSelfie = ProfileViewData.fromMap(<String, dynamic>{
        'first_name': 'Ben',
        'last_name': 'Reyes',
        'role': 'passenger',
        'selfie_url': 'selfie-url',
        'id_image_url': 'id-url',
      }, 'user-2');
      final initialsOnly = ProfileViewData.fromMap(<String, dynamic>{
        'first_name': 'Cara',
        'last_name': 'Diaz',
        'role': 'passenger',
        'id_image_url': 'id-url',
      }, 'user-3');

      expect(withProfilePicture.profileImageUrl, 'profile-picture-url');
      expect(withSelfie.profileImageUrl, 'selfie-url');
      expect(initialsOnly.profileImageUrl, isNull);
      expect(initialsOnly.initials, 'CD');
    });
  });

  group('ProfilePictureService', () {
    test('blocks another profile picture update inside seven days', () {
      final now = DateTime(2026, 6, 6);
      final data = <String, dynamic>{
        'profile_picture_updated_at': Timestamp.fromDate(
          now.subtract(const Duration(days: 3)),
        ),
      };

      expect(ProfilePictureService.canUpdateFrom(data, now: now), isFalse);
    });
  });
}
