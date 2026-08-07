import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sakaynow_buenatoda/controllers/booking_map_controller.dart';
import 'package:sakaynow_buenatoda/services/fare_settings_service.dart';
import 'package:sakaynow_buenatoda/services/location_service.dart';
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

    test(
      'returns null notice for regular unverified passenger without error',
      () {
        final controller = BookingMapController(
          passengerId: 'p3',
          passengerType: 'regular',
          isPassengerVerified: false,
          rideTrackingService: rideTrackingService,
          fareSettingsService: fareSettingsService,
        );

        expect(controller.fareNotice, isNull);
      },
    );

    test(
      'handles an initial browser location outside the service area',
      () async {
        final controller = BookingMapController(
          passengerId: 'p4',
          passengerType: 'regular',
          isPassengerVerified: false,
          locationService: const _OutsideServiceAreaLocationService(),
          rideTrackingService: rideTrackingService,
          fareSettingsService: fareSettingsService,
        );
        addTearDown(controller.dispose);

        await expectLater(controller.initialize(), completes);

        expect(controller.isInitializing, isFalse);
        expect(controller.pickupLocation, isNull);
        expect(
          controller.locationMessage,
          'Current location must be in Buenavista, Inabanga, or Getafe.',
        );
      },
    );

    test(
      'handles retrying a current location outside the service area',
      () async {
        final controller = BookingMapController(
          passengerId: 'p5',
          passengerType: 'regular',
          isPassengerVerified: false,
          locationService: const _OutsideServiceAreaLocationService(),
          rideTrackingService: rideTrackingService,
          fareSettingsService: fareSettingsService,
        );
        addTearDown(controller.dispose);

        final pickup = await controller.useCurrentLocationAsPickup();

        expect(pickup, isNull);
        expect(
          controller.locationMessage,
          'Current location must be in Buenavista, Inabanga, or Getafe.',
        );
      },
    );
  });
}

class _OutsideServiceAreaLocationService extends LocationService {
  const _OutsideServiceAreaLocationService();

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      longitude: 120.9842,
      latitude: 14.5995,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }
}
