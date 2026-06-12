import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/auth/signup_validators.dart';
import 'package:sakaynow_buenatoda/core/session/app_user.dart';

void main() {
  group('SignupValidators', () {
    test('validates email shape', () {
      expect(SignupValidators.email(null), 'Email is required');
      expect(
        SignupValidators.email('not-an-email'),
        'Enter a valid email address',
      );
      expect(SignupValidators.email(' passenger@example.com '), isNull);
    });

    test('validates names and rejects reserved admin first name', () {
      expect(
        SignupValidators.accountFirstName('admin'),
        'The name admin is reserved.',
      );
      expect(
        SignupValidators.name('J', fieldName: 'Last name'),
        'Last name must be at least 2 characters',
      );
      expect(
        SignupValidators.name('Juan1', fieldName: 'First name'),
        'First name cannot contain numbers',
      );
      expect(SignupValidators.accountFirstName('Juan'), isNull);
    });

    test('enforces passenger and driver age ranges', () {
      expect(
        SignupValidators.age(
          '12',
          minimumAge: SignupValidators.passengerMinimumAge,
        ),
        'Must be at least 13 years old',
      );
      expect(
        SignupValidators.age(
          '17',
          minimumAge: SignupValidators.driverMinimumAge,
        ),
        'Must be at least 18 years old',
      );
      expect(
        SignupValidators.age(
          '101',
          minimumAge: SignupValidators.driverMinimumAge,
        ),
        'Enter an age below 100',
      );
      expect(
        SignupValidators.age(
          '18',
          minimumAge: SignupValidators.driverMinimumAge,
        ),
        isNull,
      );
    });

    test('requires strong matching passwords', () {
      expect(
        SignupValidators.password('short1'),
        'Password must be at least 8 characters',
      );
      expect(
        SignupValidators.password('password'),
        'Use letters and at least one number',
      );
      expect(
        SignupValidators.password('pass word1'),
        'Password cannot contain spaces',
      );
      expect(SignupValidators.password('driver123'), isNull);

      expect(
        SignupValidators.confirmPassword('driver124', 'driver123'),
        'Passwords do not match',
      );
      expect(
        SignupValidators.confirmPassword('driver123', 'driver123'),
        isNull,
      );
    });
  });

  group('AppUser auth profile parsing', () {
    test('recognizes legacy verification spellings from Firestore', () {
      final user = AppUser.fromMap(<String, dynamic>{
        'first_name': 'Rica',
        'last_name': 'Santos',
        'email': 'rica@example.com',
        'role': 'driver',
        'isVerrified': true,
        'is_active': false,
        'is_banned': false,
        'account_status': 'active',
      }, 'driver-1');

      expect(user.isVerified, isTrue);
      expect(user.userRole, UserRole.driver);
      expect(user.accessState(), AccountAccessState.active);
    });
  });
}
