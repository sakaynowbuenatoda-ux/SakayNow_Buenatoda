import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapConfig {
  MapConfig._();

  static const LatLng buenavistaCenter = LatLng(10.0839, 124.1781);
  static const double defaultZoom = 14.5;
  static const double routeZoom = 15;

  static const double pickupRadiusMeters = 360;
  static const double driverNearPickupRadiusMeters = 240;
  static const double destinationArrivalRadiusMeters = 270;
  static const double passengerPickupRadiusMeters = 450;

  static const int placesSearchDebounceMs = 350;
  static const int driverLocationDistanceFilterMeters = 8;
  static const Duration driverLocationUpdateInterval = Duration(seconds: 8);
  static const Duration etaRefreshInterval = Duration(seconds: 25);

  static const double averageTricycleMetersPerSecond = 5.6;
  static const String googleApisHost = 'maps.googleapis.com';
}
