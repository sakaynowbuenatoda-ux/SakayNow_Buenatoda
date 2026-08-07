import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_config.dart';
import '../models/ride.dart';
import '../models/ride_location.dart';
import '../models/ride_status.dart';
import '../services/distance_matrix_service.dart';
import '../services/geofencing_service.dart';
import '../services/location_service.dart';
import '../services/ride_eta_service.dart';
import '../services/ride_tracking_service.dart';
import '../utils/user_facing_error_message.dart';

enum RideViewerRole { passenger, driver }

class RideTrackingController extends ChangeNotifier {
  RideTrackingController({
    required this.bookingId,
    required this.userId,
    required this.viewerRole,
    RideTrackingService? rideTrackingService,
    LocationService? locationService,
    DistanceMatrixService? distanceMatrixService,
    GeofencingService? geofencingService,
  }) : _rideTrackingService = rideTrackingService ?? RideTrackingService(),
       _locationService = locationService ?? const LocationService(),
       _rideEtaService = RideEtaService(
         distanceMatrixService:
             distanceMatrixService ?? DistanceMatrixService(),
         geofencingService: geofencingService ?? const GeofencingService(),
       );

  final String bookingId;
  final String userId;
  final RideViewerRole viewerRole;
  final RideTrackingService _rideTrackingService;
  final LocationService _locationService;
  final RideEtaService _rideEtaService;

  StreamSubscription<Ride?>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _etaTimer;
  DateTime? _lastEtaRefresh;

  Ride? ride;
  Position? driverPosition;
  bool isLoading = true;
  bool isPublishingLocation = false;
  bool isUpdatingStatus = false;
  String? errorMessage;

  bool get isDriver => viewerRole == RideViewerRole.driver;
  bool get isPassenger => viewerRole == RideViewerRole.passenger;

  LatLng get initialCameraTarget =>
      ride?.pickupLocation.latLng ??
      ride?.driverLocation?.latLng ??
      MapConfig.buenavistaCenter;

  Set<Marker> get markers {
    final activeRide = ride;
    if (activeRide == null) {
      return <Marker>{};
    }

    final markers = <Marker>{};
    final pickup = activeRide.pickupLocation.latLng;
    final dropoff = activeRide.dropoffLocation.latLng;
    final driver = activeRide.driverLocation?.latLng;

    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: pickup,
          infoWindow: InfoWindow(
            title: _locationLabel(activeRide.pickupLocation),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff_location'),
          position: dropoff,
          infoWindow: InfoWindow(
            title: _locationLabel(activeRide.dropoffLocation),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: driver,
          infoWindow: const InfoWindow(title: 'Driver location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    return markers;
  }

  String _locationLabel(RideLocation location) {
    return isDriver ? location.publicDisplayLabel : location.displayLabel;
  }

  Set<Polyline> get polylines {
    final activeRoute = ride?.route;
    if (activeRoute == null || activeRoute.polylinePoints.isEmpty) {
      return <Polyline>{};
    }

    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('ride_route'),
        points: activeRoute.polylinePoints,
        color: const Color(0xFF2E7EA7),
        width: 5,
      ),
    };
  }

  Set<Circle> get circles {
    final activeRide = ride;
    if (activeRide == null) {
      return <Circle>{};
    }

    final pickup = activeRide.pickupLocation.latLng;
    final destination = activeRide.dropoffLocation.latLng;
    final circles = <Circle>{};

    if (pickup != null) {
      circles.add(
        Circle(
          circleId: const CircleId('pickup_radius'),
          center: pickup,
          radius: MapConfig.driverNearPickupRadiusMeters,
          fillColor: const Color(0xFF157A56).withValues(alpha: 0.10),
          strokeColor: const Color(0xFF157A56),
          strokeWidth: 1,
        ),
      );
    }

    if (destination != null) {
      circles.add(
        Circle(
          circleId: const CircleId('destination_radius'),
          center: destination,
          radius: MapConfig.destinationArrivalRadiusMeters,
          fillColor: const Color(0xFFB43B2A).withValues(alpha: 0.08),
          strokeColor: const Color(0xFFB43B2A),
          strokeWidth: 1,
        ),
      );
    }

    return circles;
  }

  LatLngBounds? get visibleBounds {
    final routeBounds = ride?.route?.bounds;
    if (routeBounds != null) {
      return routeBounds;
    }

    final points = <LatLng>[
      if (ride?.pickupLocation.latLng != null) ride!.pickupLocation.latLng!,
      if (ride?.dropoffLocation.latLng != null) ride!.dropoffLocation.latLng!,
      if (ride?.driverLocation?.latLng != null) ride!.driverLocation!.latLng,
    ];

    return _boundsFromPoints(points);
  }

  Future<void> start() async {
    _rideSubscription = _rideTrackingService
        .watchRide(bookingId)
        .listen(
          (value) {
            ride = value;
            isLoading = false;
            errorMessage = value == null ? 'Ride not found.' : null;
            notifyListeners();

            if (value != null && isDriver) {
              _refreshEtaIfNeeded();
            }
          },
          onError: (Object error) {
            isLoading = false;
            errorMessage = userFacingErrorMessage(
              error,
              fallback: 'Unable to load this ride. Please try again.',
            );
            notifyListeners();
          },
        );

    if (isDriver) {
      await _startDriverLocationPublishing();

      _etaTimer = Timer.periodic(MapConfig.etaRefreshInterval, (_) {
        _refreshEtaIfNeeded(force: true);
      });
    }
  }

  Future<void> updateStatus(RideStatus status) async {
    final current = ride?.status;
    if (current != null && current != status && !current.canMoveTo(status)) {
      errorMessage =
          'This ride step is not available yet. Please follow the current trip status.';
      notifyListeners();
      return;
    }

    isUpdatingStatus = true;
    notifyListeners();

    try {
      await _rideTrackingService.updateRideStatus(
        bookingId: bookingId,
        status: status,
        changedBy: userId,
      );
      errorMessage = null;
    } on Exception catch (error) {
      errorMessage = userFacingErrorMessage(
        error,
        fallback: 'Unable to update this ride. Please try again.',
      );
    } finally {
      isUpdatingStatus = false;
      notifyListeners();
    }
  }

  Future<void> cancelRide() {
    return updateStatus(RideStatus.cancelled);
  }

  Future<void> _startDriverLocationPublishing() async {
    isPublishingLocation = true;
    notifyListeners();

    try {
      _positionSubscription = _locationService.watchPosition().listen(
        (position) {
          driverPosition = position;
          _publishDriverLocation(position);
        },
        onError: (Object error) {
          errorMessage = userFacingErrorMessage(
            error,
            fallback:
                'Unable to share your driver location. Please check location access.',
          );
          isPublishingLocation = false;
          notifyListeners();
        },
      );
      errorMessage = null;
    } on Exception catch (error) {
      errorMessage = userFacingErrorMessage(
        error,
        fallback:
            'Unable to share your driver location. Please check location access.',
      );
      isPublishingLocation = false;
      notifyListeners();
    }
  }

  Future<void> _publishDriverLocation(Position position) async {
    final activeRide = ride;
    final activeBookingId = activeRide?.isActive == true ? bookingId : null;

    try {
      await _rideTrackingService.updateDriverLocation(
        driverId: userId,
        position: position,
        activeBookingId: activeBookingId,
        isAvailable: true,
      );
      _refreshEtaIfNeeded();
    } on Exception catch (error) {
      errorMessage = userFacingErrorMessage(
        error,
        fallback: 'Unable to update your driver location right now.',
      );
      notifyListeners();
    }
  }

  Future<void> _refreshEtaIfNeeded({bool force = false}) async {
    if (!isDriver) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastEtaRefresh != null &&
        now.difference(_lastEtaRefresh!) < MapConfig.etaRefreshInterval) {
      return;
    }

    _lastEtaRefresh = now;
    await _refreshEta();
  }

  Future<void> _refreshEta() async {
    if (!isDriver) {
      return;
    }

    final activeRide = ride;
    final driverLatLng = activeRide?.driverLocation?.latLng;
    final pickup = activeRide?.pickupLocation.latLng;
    final dropoff = activeRide?.dropoffLocation.latLng;

    if (activeRide == null || driverLatLng == null) {
      return;
    }

    try {
      if ((activeRide.status == RideStatus.accepted ||
              activeRide.status == RideStatus.driverArriving ||
              activeRide.status == RideStatus.arrived) &&
          pickup != null) {
        final eta = await _rideEtaService.estimate(
          origin: driverLatLng,
          destination: pickup,
        );
        await _rideTrackingService.updateRideEta(
          bookingId: bookingId,
          driverToPickup: eta,
        );
      }

      if (activeRide.status == RideStatus.inProgress && dropoff != null) {
        final eta = await _rideEtaService.estimate(
          origin: driverLatLng,
          destination: dropoff,
        );
        await _rideTrackingService.updateRideEta(
          bookingId: bookingId,
          remainingRide: eta,
        );
      }
    } on Exception catch (error) {
      errorMessage = userFacingErrorMessage(
        error,
        fallback: 'Unable to refresh the ride estimate right now.',
      );
      notifyListeners();
    }
  }

  LatLngBounds? _boundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return null;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
