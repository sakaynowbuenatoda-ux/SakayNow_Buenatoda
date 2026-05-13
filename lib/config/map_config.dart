import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapConfig {
  MapConfig._();

  static const LatLng buenavistaCenter = LatLng(10.0839, 124.1781);
  static const LatLng serviceAreaCenter = LatLng(10.088, 124.133);
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
  static const String supportedServiceAreaLabel =
      'Buenavista, Inabanga, or Getafe';

  static const List<MapServiceArea> supportedServiceAreas = <MapServiceArea>[
    MapServiceArea(
      name: 'Buenavista',
      aliases: <String>['buenavista'],
      center: buenavistaCenter,
      searchRadiusMeters: 12000,
    ),
    MapServiceArea(
      name: 'Inabanga',
      aliases: <String>['inabanga', 'inabangga'],
      center: LatLng(10.0315, 124.0677),
      searchRadiusMeters: 14000,
    ),
    MapServiceArea(
      name: 'Getafe',
      aliases: <String>['getafe'],
      center: LatLng(10.1494, 124.1540),
      searchRadiusMeters: 12000,
    ),
  ];

  static bool mentionsSupportedServiceArea(String value) {
    final normalized = value.toLowerCase();
    return supportedServiceAreas.any(
      (area) => area.aliases.any(normalized.contains),
    );
  }
}

class MapServiceArea {
  final String name;
  final List<String> aliases;
  final LatLng center;
  final int searchRadiusMeters;

  const MapServiceArea({
    required this.name,
    required this.aliases,
    required this.center,
    required this.searchRadiusMeters,
  });
}
