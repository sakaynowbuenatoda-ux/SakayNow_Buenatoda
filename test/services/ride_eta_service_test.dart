import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sakaynow_buenatoda/models/distance_matrix_result.dart';
import 'package:sakaynow_buenatoda/services/distance_matrix_service.dart';
import 'package:sakaynow_buenatoda/services/geofencing_service.dart';
import 'package:sakaynow_buenatoda/services/ride_eta_service.dart';

void main() {
  const origin = LatLng(10.7000, 122.6260);
  const destination = LatLng(10.6800, 122.6400);

  test('uses Google Distance Matrix result when it succeeds', () async {
    final distanceMatrix = _SuccessfulDistanceMatrixService();
    final geofencing = _FixedGeofencingService();
    final service = RideEtaService(
      distanceMatrixService: distanceMatrix,
      geofencingService: geofencing,
    );

    final result = await service.estimate(
      origin: origin,
      destination: destination,
    );

    expect(result.distanceMeters, 2100);
    expect(result.durationSeconds, 420);
    expect(geofencing.distanceWasRequested, isFalse);
  });

  test('falls back to a local ETA when Distance Matrix fails', () async {
    final geofencing = _FixedGeofencingService();
    final service = RideEtaService(
      distanceMatrixService: _FailingDistanceMatrixService(),
      geofencingService: geofencing,
    );

    final result = await service.estimate(
      origin: origin,
      destination: destination,
    );

    expect(geofencing.distanceWasRequested, isTrue);
    expect(result.distanceMeters, 1250);
    expect(result.durationSeconds, 300);
    expect(result.distanceText, '1.3 km');
    expect(result.durationText, '5 mins');
  });
}

class _SuccessfulDistanceMatrixService extends DistanceMatrixService {
  @override
  Future<DistanceMatrixResult> estimate({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return const DistanceMatrixResult(
      distanceMeters: 2100,
      durationSeconds: 420,
      distanceText: '2.1 km',
      durationText: '7 mins',
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
  bool distanceWasRequested = false;

  @override
  double distanceBetweenMeters(LatLng origin, LatLng destination) {
    distanceWasRequested = true;
    return 1250;
  }

  @override
  int approximateDurationSeconds(double distanceMeters) => 300;
}
