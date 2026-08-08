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

  test('commission defaults to zero and supports an admin configured rate', () {
    expect(FareSettings.defaults.commissionRate, 0);
    expect(FareSettings.defaults.commissionLabel, '0% commission');

    final configured = FareSettings.defaults.copyWith(commissionRate: 0.125);

    expect(configured.commissionLabel, '12.5% commission');
    expect(
      configured.toFirestore(updatedBy: 'admin-1')['commission_rate'],
      0.125,
    );
  });

  test('passenger discounts and pickup add-on have backward-safe defaults', () {
    final settings = FareSettings.fromMap(const <String, dynamic>{});

    expect(settings.regularPassengerDiscountRate, 0);
    expect(settings.studentDiscountRate, 0.15);
    expect(settings.seniorCitizenDiscountRate, 0.15);
    expect(settings.driverPickupSurchargePerExtraBarangay, 5);
    expect(settings.maxDriverPickupSurcharge, 10);
  });

  test('new editable fare settings are persisted', () {
    final settings = FareSettings.defaults.copyWith(
      regularPassengerDiscountRate: 0.05,
      seniorCitizenDiscountRate: 0.2,
      driverPickupSurchargePerExtraBarangay: 7,
      maxDriverPickupSurcharge: 21,
    );
    final data = settings.toFirestore(updatedBy: 'admin-1');

    expect(data['regular_passenger_discount_rate'], 0.05);
    expect(data['senior_citizen_discount_rate'], 0.2);
    expect(data['driver_pickup_surcharge_per_extra_barangay'], 7);
    expect(data['max_driver_pickup_surcharge'], 21);
  });
}
