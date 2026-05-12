import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_config.dart';

class GeofencingService {
  const GeofencingService();

  double distanceBetweenMeters(LatLng origin, LatLng destination) {
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  bool isWithinRadius({
    required LatLng origin,
    required LatLng target,
    required double radiusMeters,
  }) {
    return distanceBetweenMeters(origin, target) <= radiusMeters;
  }

  bool isDriverNearPickup({
    required LatLng driverLocation,
    required LatLng pickupLocation,
  }) {
    return isWithinRadius(
      origin: driverLocation,
      target: pickupLocation,
      radiusMeters: MapConfig.driverNearPickupRadiusMeters,
    );
  }

  bool isDriverNearDestination({
    required LatLng driverLocation,
    required LatLng destination,
  }) {
    return isWithinRadius(
      origin: driverLocation,
      target: destination,
      radiusMeters: MapConfig.destinationArrivalRadiusMeters,
    );
  }

  bool isPassengerInsidePickupRadius({
    required LatLng passengerLocation,
    required LatLng pickupLocation,
  }) {
    return isWithinRadius(
      origin: passengerLocation,
      target: pickupLocation,
      radiusMeters: MapConfig.passengerPickupRadiusMeters,
    );
  }

  int approximateDurationSeconds(double distanceMeters) {
    return (distanceMeters / MapConfig.averageTricycleMetersPerSecond).round();
  }
}
