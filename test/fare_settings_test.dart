import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/fare_settings.dart';

void main() {
  test('passenger fare guide description uses editable fare settings', () {
    final settings = FareSettings.defaults.copyWith(
      oneBarangayFare: 35,
      buenavistaFiveBarangayFare: 45,
      outsideBuenavistaMinFare: 55,
      outsideBuenavistaMaxFare: 125,
    );

    expect(
      settings.passengerFareGuideDescription,
      'Base fare starts at PHP 35, up to 5 barangays is PHP 45, and extended routes are PHP 55-PHP 125.',
    );
  });

  test(
    'passenger student discount description uses editable discount rate',
    () {
      final settings = FareSettings.defaults.copyWith(studentDiscountRate: 0.2);

      expect(
        settings.passengerStudentDiscountDescription,
        'Verified students receive 20% off eligible rides.',
      );
    },
  );
}
