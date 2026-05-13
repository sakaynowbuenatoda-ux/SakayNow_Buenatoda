import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/session/app_user.dart';

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
  });
}
