import 'package:geolocator/geolocator.dart';

import '../config/map_config.dart';

enum LocationAccessStatus { ready, serviceDisabled, denied, deniedForever }

class LocationAccessResult {
  final LocationAccessStatus status;
  final String message;

  const LocationAccessResult({required this.status, required this.message});

  bool get isReady => status == LocationAccessStatus.ready;
}

class LocationAccessException implements Exception {
  final LocationAccessResult result;

  const LocationAccessException(this.result);

  @override
  String toString() => result.message;
}

class LocationService {
  const LocationService();

  Future<LocationAccessResult> ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationAccessResult(
        status: LocationAccessStatus.serviceDisabled,
        message: 'Turn on device location services to use live ride tracking.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationAccessResult(
        status: LocationAccessStatus.denied,
        message: 'Location permission is needed to find pickup points.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationAccessResult(
        status: LocationAccessStatus.deniedForever,
        message:
            'Location permission is permanently denied. Enable it in system settings.',
      );
    }

    return const LocationAccessResult(
      status: LocationAccessStatus.ready,
      message: 'Location access ready.',
    );
  }

  Future<Position> getCurrentPosition() async {
    final access = await ensureLocationAccess();
    if (!access.isReady) {
      throw LocationAccessException(access);
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Stream<Position> watchPosition({
    int distanceFilter = MapConfig.driverLocationDistanceFilterMeters,
  }) async* {
    final access = await ensureLocationAccess();
    if (!access.isReady) {
      throw LocationAccessException(access);
    }

    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
