import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/session/account_flags.dart';

void main() {
  test(
    'legacy verification remains valid when the canonical flag conflicts',
    () {
      expect(
        isVerifiedAccountData(<String, dynamic>{
          'is_verified': false,
          'isVerified': true,
        }),
        isTrue,
      );
    },
  );

  test('accepts the historical misspelled verification flag', () {
    expect(
      isVerifiedAccountData(<String, dynamic>{'isVerrified': 'true'}),
      isTrue,
    );
  });

  test('does not verify an account when every known flag is false', () {
    expect(
      isVerifiedAccountData(<String, dynamic>{
        'is_verified': false,
        'isVerified': false,
        'isVerrified': false,
      }),
      isFalse,
    );
  });
}
