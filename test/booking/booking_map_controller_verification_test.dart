import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/controllers/booking_map_controller.dart';
import 'package:sakaynow_buenatoda/services/fare_settings_service.dart';
import 'package:sakaynow_buenatoda/services/ride_tracking_service.dart';

void main() {
  group('BookingMapController unverified fare notice tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late RideTrackingService rideTrackingService;
    late FareSettingsService fareSettingsService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      rideTrackingService = RideTrackingService(firestore: fakeFirestore);
      fareSettingsService = FareSettingsService(firestore: fakeFirestore);
    });

    test('returns unlock notice for unverified student', () {
      final controller = BookingMapController(
        passengerId: 'p1',
        passengerType: 'student',
        isPassengerVerified: false,
        rideTrackingService: rideTrackingService,
        fareSettingsService: fareSettingsService,
      );

      expect(
        controller.fareNotice,
        'Student discount unlocks after account verification.',
      );
    });

    test('returns unlock notice for unverified senior citizen', () {
      final controller = BookingMapController(
        passengerId: 'p2',
        passengerType: 'senior_citizen',
        isPassengerVerified: false,
        rideTrackingService: rideTrackingService,
        fareSettingsService: fareSettingsService,
      );

      expect(
        controller.fareNotice,
        'Senior Citizen discount unlocks after account verification.',
      );
    });

    test('returns null notice for regular unverified passenger without error', () {
      final controller = BookingMapController(
        passengerId: 'p3',
        passengerType: 'regular',
        isPassengerVerified: false,
        rideTrackingService: rideTrackingService,
        fareSettingsService: fareSettingsService,
      );

      expect(controller.fareNotice, isNull);
    });
  });
}
