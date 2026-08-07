import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/distance_matrix_result.dart';
import 'distance_matrix_service.dart';
import 'geofencing_service.dart';

/// Resolves a live ride ETA and falls back to a local distance estimate when
/// Google Distance Matrix is unavailable.
class RideEtaService {
  RideEtaService({
    DistanceMatrixService? distanceMatrixService,
    GeofencingService? geofencingService,
  }) : _distanceMatrixService =
           distanceMatrixService ?? DistanceMatrixService(),
       _geofencingService = geofencingService ?? const GeofencingService();

  final DistanceMatrixService _distanceMatrixService;
  final GeofencingService _geofencingService;

  Future<DistanceMatrixResult> estimate({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      return await _distanceMatrixService.estimate(
        origin: origin,
        destination: destination,
      );
    } on Exception {
      final distance = _geofencingService.distanceBetweenMeters(
        origin,
        destination,
      );
      final duration = _geofencingService.approximateDurationSeconds(distance);

      return DistanceMatrixResult(
        distanceMeters: distance.round(),
        durationSeconds: duration,
        distanceText: distance < 1000
            ? '${distance.round()} m'
            : '${(distance / 1000).toStringAsFixed(1)} km',
        durationText: '${(duration / 60).ceil()} mins',
      );
    }
  }
}
