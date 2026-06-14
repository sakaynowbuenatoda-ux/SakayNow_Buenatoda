import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/fare_estimate.dart';
import 'package:sakaynow_buenatoda/models/fare_settings.dart';
import 'package:sakaynow_buenatoda/models/ride_location.dart';
import 'package:sakaynow_buenatoda/services/fare_service.dart';

void main() {
  FareEstimate estimate({required int amount}) {
    return FareEstimate(
      amount: amount,
      ruleCode: 'test_rule',
      ruleLabel: 'Test rule',
      distanceMeters: 1000,
      barangayHopEstimate: 1,
      isOutsideBuenavista: false,
    );
  }

  test('applies 15 percent discount for verified students', () {
    final discounted = estimate(
      amount: 25,
    ).applyStudentDiscount(isEligible: true);

    expect(discounted.amount, 21);
    expect(discounted.baseAmount, 25);
    expect(discounted.discountAmount, 4);
    expect(discounted.discountRate, 0.15);
    expect(discounted.hasDiscount, isTrue);
  });

  test('keeps base fare when student discount is not eligible', () {
    final regularFare = estimate(
      amount: 30,
    ).applyStudentDiscount(isEligible: false);

    expect(regularFare.amount, 30);
    expect(regularFare.baseAmount, 30);
    expect(regularFare.discountAmount, 0);
    expect(regularFare.hasDiscount, isFalse);
  });

  test('uses editable one barangay fare settings', () {
    const service = FareService();
    final settings = FareSettings.defaults.copyWith(
      oneBarangayFare: 35,
      buenavistaFiveBarangayFare: 40,
    );

    final fare = service.estimateFare(
      pickupLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      dropoffLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      distanceMeters: 900,
      settings: settings,
    );

    expect(fare.amount, 35);
    expect(fare.baseAmount, 35);
    expect(fare.ruleCode, 'buenavista_one_barangay');
  });

  test('uses editable distance fare settings', () {
    const service = FareService();
    final settings = FareSettings.defaults.copyWith(
      outsideBuenavistaMinFare: 35,
      outsideBuenavistaNineKmFare: 50,
      outsideBuenavistaTwelveKmFare: 75,
      outsideBuenavistaSixteenKmFare: 90,
      outsideBuenavistaMaxFare: 120,
    );

    final fare = service.estimateFare(
      pickupLocation: const RideLocation(address: 'Poblacion, Buenavista'),
      dropoffLocation: const RideLocation(address: 'Getafe Port'),
      distanceMeters: 10000,
      settings: settings,
    );

    expect(fare.amount, 75);
    expect(fare.ruleCode, 'outside_buenavista_distance');
  });

  test('uses editable student discount rate', () {
    const service = FareService();
    final settings = FareSettings.defaults.copyWith(
      oneBarangayFare: 40,
      buenavistaFiveBarangayFare: 40,
      studentDiscountRate: 0.5,
    );

    final fare = service.estimateFare(
      pickupLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      dropoffLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      distanceMeters: 900,
      studentDiscountEligible: true,
      settings: settings,
    );

    expect(fare.amount, 20);
    expect(fare.baseAmount, 40);
    expect(fare.discountRate, 0.5);
    expect(fare.discountLabel, '50% student discount');
  });

  test('adds no driver pickup surcharge within one barangay range', () {
    const service = FareService();

    final fare = service.estimateFare(
      pickupLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      dropoffLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      distanceMeters: 900,
      driverToPickupDistanceMeters: FareService.oneBarangayRangeMeters,
    );

    expect(fare.amount, 25);
    expect(fare.driverPickupSurcharge, 0);
    expect(fare.driverPickupBarangayHopEstimate, 1);
  });

  test('adds five pesos when driver is more than one barangay away', () {
    const service = FareService();

    final fare = service.estimateFare(
      pickupLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      dropoffLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      distanceMeters: 900,
      driverToPickupDistanceMeters: FareService.oneBarangayRangeMeters + 1,
    );

    expect(fare.amount, 30);
    expect(fare.baseAmount, 30);
    expect(fare.driverPickupSurcharge, 5);
    expect(fare.driverPickupBarangayHopEstimate, 2);
  });

  test('limits driver pickup surcharge to ten pesos', () {
    const service = FareService();

    final fare = service.estimateFare(
      pickupLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      dropoffLocation: const RideLocation(
        address: 'Poblacion, Buenavista',
        name: 'Poblacion',
      ),
      distanceMeters: 900,
      driverToPickupDistanceMeters: 9000,
    );

    expect(fare.amount, 35);
    expect(fare.driverPickupSurcharge, 10);
    expect(fare.driverPickupBarangayHopEstimate, greaterThan(2));
  });
}
