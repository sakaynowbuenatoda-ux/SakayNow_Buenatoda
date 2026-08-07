import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sakaynow_buenatoda/controllers/ride_tracking_controller.dart';
import 'package:sakaynow_buenatoda/models/distance_matrix_result.dart';
import 'package:sakaynow_buenatoda/services/distance_matrix_service.dart';
import 'package:sakaynow_buenatoda/services/geofencing_service.dart';
import 'package:sakaynow_buenatoda/services/location_service.dart';
import 'package:sakaynow_buenatoda/services/ride_tracking_service.dart';

void main() {
  test('passenger monitoring never calculates or writes ride ETA', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedAcceptedRide(firestore);
    final distanceMatrix = _CountingDistanceMatrixService();
    final controller = RideTrackingController(
      bookingId: 'booking-1',
      userId: 'passenger-1',
      viewerRole: RideViewerRole.passenger,
      rideTrackingService: RideTrackingService(firestore: firestore),
      distanceMatrixService: distanceMatrix,
      geofencingService: _FixedGeofencingService(),
    );
    addTearDown(controller.dispose);

    await controller.start();
    await _waitUntil(() => controller.ride != null);

    final booking = await firestore
        .collection('bookings')
        .doc('booking-1')
        .get();
    expect(distanceMatrix.callCount, 0);
    expect(booking.data(), isNot(contains('eta')));
  });

  test('driver monitoring writes the fallback ETA after API failure', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedAcceptedRide(firestore);
    final controller = RideTrackingController(
      bookingId: 'booking-1',
      userId: 'driver-1',
      viewerRole: RideViewerRole.driver,
      rideTrackingService: RideTrackingService(firestore: firestore),
      locationService: const _SilentLocationService(),
      distanceMatrixService: _FailingDistanceMatrixService(),
      geofencingService: _FixedGeofencingService(),
    );
    addTearDown(controller.dispose);

    await controller.start();
    await _waitUntil(() async {
      final booking = await firestore
          .collection('bookings')
          .doc('booking-1')
          .get();
      return booking.data()?['eta'] is Map;
    });

    final booking = await firestore
        .collection('bookings')
        .doc('booking-1')
        .get();
    final eta = booking.data()!['eta'] as Map<String, dynamic>;
    expect(eta['driver_to_pickup_distance_meters'], 1250);
    expect(eta['driver_to_pickup_duration_seconds'], 300);
  });
}

Future<void> _seedAcceptedRide(FakeFirebaseFirestore firestore) {
  return firestore.collection('bookings').doc('booking-1').set(
    <String, dynamic>{
      'booking_id': 'booking-1',
      'passenger_id': 'passenger-1',
      'driver_id': 'driver-1',
      'status': 'accepted',
      'pickup_location': <String, dynamic>{
        'address': 'Buenavista Plaza',
        'latitude': 10.7000,
        'longitude': 122.6260,
      },
      'dropoff_location': <String, dynamic>{
        'address': 'New Poblacion',
        'latitude': 10.6800,
        'longitude': 122.6400,
      },
      'driver_location': <String, dynamic>{
        'driver_id': 'driver-1',
        'latitude': 10.6900,
        'longitude': 122.6300,
      },
    },
  );
}

Future<void> _waitUntil(FutureOr<bool> Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  fail('Timed out waiting for the expected ETA state.');
}

class _SilentLocationService extends LocationService {
  const _SilentLocationService();

  @override
  Stream<Position> watchPosition({int distanceFilter = 10}) {
    return const Stream<Position>.empty();
  }
}

class _CountingDistanceMatrixService extends DistanceMatrixService {
  int callCount = 0;

  @override
  Future<DistanceMatrixResult> estimate({
    required LatLng origin,
    required LatLng destination,
  }) async {
    callCount++;
    return const DistanceMatrixResult(
      distanceMeters: 1000,
      durationSeconds: 240,
      distanceText: '1 km',
      durationText: '4 mins',
    );
  }
}

class _FailingDistanceMatrixService extends DistanceMatrixService {
  @override
  Future<DistanceMatrixResult> estimate({
    required LatLng origin,
    required LatLng destination,
  }) {
    throw Exception('Distance Matrix unavailable');
  }
}

class _FixedGeofencingService extends GeofencingService {
  @override
  double distanceBetweenMeters(LatLng origin, LatLng destination) => 1250;

  @override
  int approximateDurationSeconds(double distanceMeters) => 300;
}
