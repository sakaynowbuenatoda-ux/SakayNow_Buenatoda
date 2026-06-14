import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_config.dart';
import '../models/distance_matrix_result.dart';
import '../models/fare_estimate.dart';
import '../models/fare_settings.dart';
import '../models/passenger_payment_method.dart';
import '../models/place_prediction.dart';
import '../models/ride.dart';
import '../models/ride_location.dart';
import '../models/route_result.dart';
import '../services/distance_matrix_service.dart';
import '../services/fare_service.dart';
import '../services/fare_settings_service.dart';
import '../services/google_directions_service.dart';
import '../services/google_places_service.dart';
import '../services/location_service.dart';
import '../services/ride_tracking_service.dart';
import '../utils/user_facing_error_message.dart';
import '../widgets/maps/map_marker_icons.dart';

enum BookingLocationTarget { pickup, dropoff }

class BookingMapController extends ChangeNotifier {
  BookingMapController({
    required this.passengerId,
    String? passengerType,
    bool? isPassengerVerified,
    LocationService? locationService,
    GooglePlacesService? placesService,
    GoogleDirectionsService? directionsService,
    DistanceMatrixService? distanceMatrixService,
    RideTrackingService? rideTrackingService,
    FareService? fareService,
    FareSettingsService? fareSettingsService,
  }) : _locationService = locationService ?? const LocationService(),
       _placesService = placesService ?? GooglePlacesService(),
       _directionsService = directionsService ?? GoogleDirectionsService(),
       _distanceMatrixService =
           distanceMatrixService ?? DistanceMatrixService(),
       _rideTrackingService = rideTrackingService ?? RideTrackingService(),
       _fareService = fareService ?? const FareService(),
       _fareSettingsService = fareSettingsService ?? FareSettingsService() {
    if (passengerType != null || isPassengerVerified != null) {
      final normalizedPassengerType = passengerType?.trim().toLowerCase();
      passengerFareProfile = PassengerFareProfile(
        userId: passengerId,
        passengerType: normalizedPassengerType == 'student'
            ? 'student'
            : 'regular',
        isVerified: isPassengerVerified == true,
      );
    }
  }

  final String passengerId;
  final LocationService _locationService;
  final GooglePlacesService _placesService;
  final GoogleDirectionsService _directionsService;
  final DistanceMatrixService _distanceMatrixService;
  final RideTrackingService _rideTrackingService;
  final FareService _fareService;
  final FareSettingsService _fareSettingsService;

  bool isInitializing = true;
  bool isPickupSearching = false;
  bool isDropoffSearching = false;
  bool isRouteLoading = false;
  bool isBookingLoading = false;
  String? errorMessage;
  String? locationMessage;
  Position? currentPosition;
  RideLocation? pickupLocation;
  RideLocation? dropoffLocation;
  LatLng? cameraTarget;
  RouteResult? route;
  DistanceMatrixResult? estimate;
  FareEstimate? fareEstimate;
  FareSettings fareSettings = FareSettings.defaults;
  bool isFareSettingsLoading = true;
  String? fareSettingsError;
  PassengerFareProfile? passengerFareProfile;
  MapMarkerIcons? markerIcons;
  List<PlacePrediction> pickupPredictions = <PlacePrediction>[];
  List<PlacePrediction> dropoffPredictions = <PlacePrediction>[];

  int _pickupSearchToken = 0;
  int _dropoffSearchToken = 0;
  bool _isPickupCurrentLocation = false;
  StreamSubscription<FareSettings>? _fareSettingsSubscription;

  bool get isPickupCurrentLocation => _isPickupCurrentLocation;
  bool get isStudentDiscountEligible =>
      passengerFareProfile?.isVerifiedStudent ?? false;

  String? get fareNotice {
    final activeFare = fareEstimate;
    final profile = passengerFareProfile;
    if (activeFare?.hasDiscount == true) {
      final label = activeFare!.discountLabel ?? 'Student discount';
      return '$label applied. Saved ${activeFare.discountAmountLabel} from ${activeFare.baseAmountLabel}.';
    }

    if (profile?.isStudent == true && profile?.isVerified != true) {
      return 'Student discount unlocks after account verification.';
    }

    if (fareSettingsError != null) {
      return fareSettingsError;
    }

    return null;
  }

  LatLng get initialCameraTarget =>
      cameraTarget ??
      currentLatLng ??
      pickupLocation?.latLng ??
      MapConfig.buenavistaCenter;

  LatLng? get currentLatLng {
    final position = currentPosition;
    if (position == null) {
      return null;
    }

    return LatLng(position.latitude, position.longitude);
  }

  bool get canCreateBooking {
    return passengerId.isNotEmpty &&
        pickupLocation?.hasCoordinates == true &&
        dropoffLocation?.hasCoordinates == true &&
        route != null &&
        !isBookingLoading;
  }

  Stream<List<AvailableDriver>> watchAvailableDrivers() {
    return _rideTrackingService.watchAvailableDrivers();
  }

  Stream<Ride?> watchPassengerActiveRide() {
    return _rideTrackingService.watchPassengerActiveRide(passengerId);
  }

  FareEstimate? fareEstimateForDriver(AvailableDriver driver) {
    final selectedRoute = route;
    if (selectedRoute == null ||
        pickupLocation == null ||
        dropoffLocation == null) {
      return fareEstimate;
    }

    return _estimateFare(
      distanceMeters: estimate?.distanceMeters ?? selectedRoute.distanceMeters,
      driverToPickupDistanceMeters: driverToPickupDistanceMeters(driver),
    );
  }

  int? driverToPickupDistanceMeters(AvailableDriver driver) {
    final pickup = pickupLocation?.latLng;
    if (pickup == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      driver.location.latitude,
      driver.location.longitude,
      pickup.latitude,
      pickup.longitude,
    ).round();
  }

  Set<Marker> get markers {
    final markers = <Marker>{};
    final current = currentLatLng;
    final pickup = pickupLocation?.latLng;
    final dropoff = dropoffLocation?.latLng;

    if (current != null && !_sameLatLng(current, pickup)) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: current,
          infoWindow: const InfoWindow(title: 'Current location'),
          icon:
              markerIcons?.current ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: pickup,
          infoWindow: InfoWindow(title: pickupLocation?.address ?? 'Pickup'),
          draggable: true,
          onDragEnd: selectPickupFromPin,
          icon:
              markerIcons?.pickup ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    if (dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff_location'),
          position: dropoff,
          infoWindow: InfoWindow(title: dropoffLocation?.address ?? 'Drop-off'),
          draggable: true,
          onDragEnd: selectDropoffFromPin,
          icon: markerIcons?.dropoff ?? BitmapDescriptor.defaultMarker,
        ),
      );
    }

    return markers;
  }

  Set<Polyline> get polylines {
    final activeRoute = route;
    if (activeRoute == null || activeRoute.polylinePoints.isEmpty) {
      return <Polyline>{};
    }

    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('selected_route'),
        points: activeRoute.polylinePoints,
        color: const Color(0xFF2E7EA7),
        width: 5,
      ),
    };
  }

  Set<Circle> get circles {
    final pickup = pickupLocation?.latLng;
    if (pickup == null) {
      return <Circle>{};
    }

    return <Circle>{
      Circle(
        circleId: const CircleId('pickup_radius'),
        center: pickup,
        radius: MapConfig.pickupRadiusMeters,
        fillColor: const Color(0xFF157A56).withValues(alpha: 0.12),
        strokeColor: const Color(0xFF157A56),
        strokeWidth: 1,
      ),
    };
  }

  Future<void> initialize() async {
    isInitializing = true;
    errorMessage = null;
    _watchFareSettings();
    notifyListeners();

    try {
      await _loadPassengerFareProfileIfNeeded();
      currentPosition = await _locationService.getCurrentPosition();
      pickupLocation = await _resolveCurrentPositionLocation();
      _isPickupCurrentLocation = true;
      cameraTarget = pickupLocation!.latLng;
      locationMessage = null;
    } on Exception catch (error) {
      locationMessage = userFacingErrorMessage(
        error,
        fallback:
            'Unable to use your current location. Please set your pickup manually.',
      );
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadPassengerFareProfileIfNeeded() async {
    if (passengerFareProfile != null || passengerId.isEmpty) {
      return;
    }

    try {
      passengerFareProfile = await _rideTrackingService
          .loadPassengerFareProfile(passengerId);
    } on Exception {
      passengerFareProfile = null;
    }
  }

  void setMarkerIcons(MapMarkerIcons icons) {
    markerIcons = icons;
    notifyListeners();
  }

  Future<RideLocation?> useCurrentLocationAsPickup() async {
    try {
      currentPosition = await _locationService.getCurrentPosition();
      final location = await _resolveCurrentPositionLocation();
      locationMessage = null;
      errorMessage = null;
      await _setLocation(
        target: BookingLocationTarget.pickup,
        location: location,
        isCurrentPickup: true,
      );
      return pickupLocation;
    } on Exception catch (error) {
      locationMessage = userFacingErrorMessage(
        error,
        fallback:
            'Unable to use your current location. Please set your pickup manually.',
      );
      notifyListeners();
      return null;
    }
  }

  Future<void> searchPickup(String query) async {
    final token = ++_pickupSearchToken;
    isPickupSearching = true;
    notifyListeners();

    try {
      final results = await _placesService.autocomplete(
        input: query,
        locationBias: currentLatLng ?? MapConfig.buenavistaCenter,
      );
      if (token == _pickupSearchToken) {
        pickupPredictions = results;
        errorMessage = null;
      }
    } on Exception catch (error) {
      if (token == _pickupSearchToken) {
        errorMessage = userFacingErrorMessage(
          error,
          fallback: 'Unable to search pickup locations. Please try again.',
        );
        pickupPredictions = <PlacePrediction>[];
      }
    } finally {
      if (token == _pickupSearchToken) {
        isPickupSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchDropoff(String query) async {
    final token = ++_dropoffSearchToken;
    isDropoffSearching = true;
    notifyListeners();

    try {
      final results = await _placesService.autocomplete(
        input: query,
        locationBias: currentLatLng ?? MapConfig.buenavistaCenter,
      );
      if (token == _dropoffSearchToken) {
        dropoffPredictions = results;
        errorMessage = null;
      }
    } on Exception catch (error) {
      if (token == _dropoffSearchToken) {
        errorMessage = userFacingErrorMessage(
          error,
          fallback: 'Unable to search drop-off locations. Please try again.',
        );
        dropoffPredictions = <PlacePrediction>[];
      }
    } finally {
      if (token == _dropoffSearchToken) {
        isDropoffSearching = false;
        notifyListeners();
      }
    }
  }

  Future<RideLocation> selectPickup(PlacePrediction prediction) async {
    final details = await _placesService.fetchDetails(prediction.placeId);
    final location = details.toRideLocation();
    await _setLocation(
      target: BookingLocationTarget.pickup,
      location: location,
    );
    return location;
  }

  Future<RideLocation> selectDropoff(PlacePrediction prediction) async {
    final details = await _placesService.fetchDetails(prediction.placeId);
    final location = details.toRideLocation();
    await _setLocation(
      target: BookingLocationTarget.dropoff,
      location: location,
    );
    return location;
  }

  Future<RideLocation> selectPickupFromPin(LatLng location) {
    return _selectLocationFromPin(
      target: BookingLocationTarget.pickup,
      location: location,
    );
  }

  Future<RideLocation> selectDropoffFromPin(LatLng location) async {
    return _selectLocationFromPin(
      target: BookingLocationTarget.dropoff,
      location: location,
    );
  }

  Future<RideLocation> selectResolvedLocation({
    required BookingLocationTarget target,
    required RideLocation location,
  }) async {
    await _setLocation(target: target, location: location);
    return location;
  }

  Future<RideLocation> selectKnownLocation({
    required BookingLocationTarget target,
    required String label,
    required String address,
    String? name,
    String? placeId,
    bool useLabelAsName = true,
    double? latitude,
    double? longitude,
  }) async {
    if (latitude != null && longitude != null) {
      final latLng = LatLng(latitude, longitude);
      if (!_placesService.isWithinSupportedServiceArea(latLng)) {
        throw StateError(
          'Select a location in ${MapConfig.supportedServiceAreaLabel} only.',
        );
      }

      final location = RideLocation(
        address: address,
        name: _knownLocationName(
          explicitName: name,
          fallbackLabel: label,
          useFallbackLabel: useLabelAsName,
        ),
        placeId: _nullableString(placeId),
        latitude: latitude,
        longitude: longitude,
      );
      await _setLocation(target: target, location: location);
      return location;
    }

    final results = await _placesService.autocomplete(
      input: address,
      locationBias: currentLatLng ?? MapConfig.buenavistaCenter,
    );
    if (results.isEmpty) {
      throw StateError('Unable to find $label on the map.');
    }

    final details = await _placesService.fetchDetails(results.first.placeId);
    final location = details.toRideLocation();
    await _setLocation(target: target, location: location);
    return location;
  }

  String? _knownLocationName({
    required String? explicitName,
    required String fallbackLabel,
    required bool useFallbackLabel,
  }) {
    final name = _nullableString(explicitName);
    if (name != null) {
      return name;
    }

    return useFallbackLabel ? fallbackLabel : null;
  }

  String? _nullableString(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<bool> resolveTypedLocations({
    required String pickupText,
    required String dropoffText,
  }) async {
    errorMessage = null;
    notifyListeners();

    try {
      if (_shouldResolveTypedLocation(pickupLocation, pickupText)) {
        final pickup = await _resolveTypedLocation(pickupText);
        await _setLocation(
          target: BookingLocationTarget.pickup,
          location: pickup,
          refresh: false,
          isCurrentPickup: _isCurrentLocationText(pickupText),
        );
      }

      if (_shouldResolveTypedLocation(dropoffLocation, dropoffText)) {
        final dropoff = await _resolveTypedLocation(dropoffText);
        await _setLocation(
          target: BookingLocationTarget.dropoff,
          location: dropoff,
          refresh: false,
        );
      }

      await refreshRoute();
      return canCreateBooking;
    } on Exception catch (error) {
      errorMessage = userFacingErrorMessage(
        error,
        fallback: 'Unable to prepare this route. Please check both locations.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<RideLocation> _selectLocationFromPin({
    required BookingLocationTarget target,
    required LatLng location,
  }) async {
    if (!_placesService.isWithinSupportedServiceArea(location)) {
      throw StateError(
        'Select a location in ${MapConfig.supportedServiceAreaLabel} only.',
      );
    }

    String address;
    try {
      address = await _placesService.reverseGeocode(location);
    } on Exception {
      address =
          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    }

    final rideLocation = RideLocation(
      address: address.isEmpty ? 'Pinned location' : address,
      name: 'Pinned location',
      latitude: location.latitude,
      longitude: location.longitude,
    );

    await _setLocation(target: target, location: rideLocation);
    return rideLocation;
  }

  bool _sameLatLng(LatLng? a, LatLng? b) {
    if (a == null || b == null) {
      return false;
    }

    const tolerance = 0.00003;
    return (a.latitude - b.latitude).abs() < tolerance &&
        (a.longitude - b.longitude).abs() < tolerance;
  }

  Future<RideLocation> _resolveTypedLocation(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw StateError('Enter a pickup and drop-off location first.');
    }

    if (normalized.toLowerCase() == 'current location' &&
        currentPosition != null) {
      return _resolveCurrentPositionLocation();
    }

    final results = await _placesService.autocomplete(
      input: normalized,
      locationBias: currentLatLng ?? MapConfig.buenavistaCenter,
    );
    if (results.isEmpty) {
      throw StateError('No matching place found for "$normalized".');
    }

    final details = await _placesService.fetchDetails(results.first.placeId);
    return details.toRideLocation();
  }

  Future<void> _setLocation({
    required BookingLocationTarget target,
    required RideLocation location,
    bool refresh = true,
    bool isCurrentPickup = false,
  }) async {
    if (target == BookingLocationTarget.pickup) {
      pickupLocation = location;
      pickupPredictions = <PlacePrediction>[];
      _isPickupCurrentLocation = isCurrentPickup;
    } else {
      dropoffLocation = location;
      dropoffPredictions = <PlacePrediction>[];
    }

    cameraTarget = location.latLng ?? cameraTarget;

    errorMessage = null;
    if (refresh) {
      await refreshRoute();
    } else {
      notifyListeners();
    }
  }

  bool _shouldResolveTypedLocation(RideLocation? current, String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return false;
    }

    if (current?.hasCoordinates != true) {
      return true;
    }

    if (_isPickupCurrentLocation && _isCurrentLocationText(normalized)) {
      return false;
    }

    final typed = normalized.toLowerCase();
    final address = current!.address.trim().toLowerCase();
    final name = current.name?.trim().toLowerCase();

    return address != typed && name != typed;
  }

  bool _isCurrentLocationText(String value) {
    return value.trim().toLowerCase() == 'current location';
  }

  void clearPickupPredictions() {
    pickupPredictions = <PlacePrediction>[];
    notifyListeners();
  }

  void clearDropoffPredictions() {
    dropoffPredictions = <PlacePrediction>[];
    notifyListeners();
  }

  Future<RideLocation> _resolveCurrentPositionLocation() async {
    final position = currentPosition;
    if (position == null) {
      throw StateError('Current location is not available yet.');
    }

    final location = LatLng(position.latitude, position.longitude);
    if (!_placesService.isWithinSupportedServiceArea(location)) {
      throw StateError(
        'Current location must be in ${MapConfig.supportedServiceAreaLabel}.',
      );
    }

    try {
      final knownPlace = await _placesService.nearestKnownPlace(location);
      if (knownPlace != null) {
        return RideLocation(
          address: knownPlace.address,
          name: knownPlace.name,
          placeId: knownPlace.placeId,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      }
    } on Exception {
      // Fall back to reverse geocoding below.
    }

    String address;
    try {
      address = await _placesService.reverseGeocode(location);
    } on Exception {
      address =
          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    }

    final normalizedAddress = address.trim();
    return RideLocation(
      address: normalizedAddress.isEmpty
          ? '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
          : normalizedAddress,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  Future<void> refreshRoute() async {
    final pickup = pickupLocation?.latLng;
    final dropoff = dropoffLocation?.latLng;
    if (pickup == null || dropoff == null) {
      route = null;
      estimate = null;
      fareEstimate = null;
      notifyListeners();
      return;
    }

    isRouteLoading = true;
    notifyListeners();

    try {
      final fetchedRoute = await _directionsService.fetchRoute(
        origin: pickup,
        destination: dropoff,
      );
      route = fetchedRoute;

      try {
        estimate = await _distanceMatrixService.estimate(
          origin: pickup,
          destination: dropoff,
        );
      } on Exception {
        estimate = null;
      }

      fareEstimate = _estimateFare(
        distanceMeters: estimate?.distanceMeters ?? fetchedRoute.distanceMeters,
      );
      errorMessage = null;
    } on Exception {
      _useApproximateRoute(origin: pickup, destination: dropoff);
    } catch (_) {
      _useApproximateRoute(origin: pickup, destination: dropoff);
    } finally {
      isRouteLoading = false;
      notifyListeners();
    }
  }

  void _useApproximateRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    route = _buildApproximateRoute(origin: origin, destination: destination);
    fareEstimate = _estimateFare(distanceMeters: route!.distanceMeters);
    estimate = null;
    errorMessage = null;
  }

  FareEstimate _estimateFare({
    required int distanceMeters,
    int? driverToPickupDistanceMeters,
  }) {
    return _fareService.estimateFare(
      pickupLocation: pickupLocation!,
      dropoffLocation: dropoffLocation!,
      distanceMeters: distanceMeters,
      studentDiscountEligible: isStudentDiscountEligible,
      settings: fareSettings,
      driverToPickupDistanceMeters: driverToPickupDistanceMeters,
    );
  }

  void _watchFareSettings() {
    if (_fareSettingsSubscription != null) {
      return;
    }

    _fareSettingsSubscription = _fareSettingsService.watchSettings().listen(
      (settings) {
        fareSettings = settings;
        isFareSettingsLoading = false;
        fareSettingsError = null;
        _refreshFareEstimateFromCurrentRoute();
        notifyListeners();
      },
      onError: (Object _) {
        isFareSettingsLoading = false;
        fareSettingsError =
            'Unable to load the latest fare guide. Estimated fares are shown for now.';
        notifyListeners();
      },
    );
  }

  void _refreshFareEstimateFromCurrentRoute() {
    final selectedRoute = route;
    if (selectedRoute == null ||
        pickupLocation == null ||
        dropoffLocation == null) {
      return;
    }

    fareEstimate = _estimateFare(
      distanceMeters: estimate?.distanceMeters ?? selectedRoute.distanceMeters,
    );
  }

  RouteResult _buildApproximateRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    final directDistanceMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final routeDistanceMeters = (directDistanceMeters * 1.2).round();
    final durationSeconds =
        routeDistanceMeters ~/ MapConfig.averageTricycleMetersPerSecond;
    final points = <LatLng>[origin, destination];

    return RouteResult(
      encodedPolyline: RouteResult.encodePolyline(points),
      polylinePoints: points,
      distanceMeters: routeDistanceMeters,
      durationSeconds: durationSeconds,
      distanceText: _formatDistance(routeDistanceMeters),
      durationText: _formatDuration(durationSeconds),
      bounds: _boundsFor(origin, destination),
    );
  }

  LatLngBounds _boundsFor(LatLng a, LatLng b) {
    final southwest = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final northeast = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );

    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).ceil();
    return '$minutes min';
  }

  Future<Ride?> findActiveRide() {
    return _rideTrackingService.findPassengerActiveRide(passengerId);
  }

  Future<String?> createBooking({
    String? preferredDriverId,
    PassengerPaymentMethod? paymentMethod,
  }) async {
    final pickup = pickupLocation;
    final dropoff = dropoffLocation;
    final selectedRoute = route;

    if (pickup == null || dropoff == null || selectedRoute == null) {
      errorMessage = 'Select a pickup and drop-off location first.';
      notifyListeners();
      return null;
    }

    isBookingLoading = true;
    notifyListeners();

    try {
      final activeRide = await _rideTrackingService.findPassengerActiveRide(
        passengerId,
      );
      if (activeRide != null) {
        errorMessage = 'You already have an active ride.';
        return activeRide.bookingId;
      }

      final bookingId = await _rideTrackingService.createBooking(
        passengerId: passengerId,
        pickupLocation: pickup,
        dropoffLocation: dropoff,
        route: selectedRoute,
        estimate: estimate,
        fareEstimate: fareEstimate,
        paymentMethod:
            paymentMethod ?? PassengerPaymentMethod.cash(userId: passengerId),
        preferredDriverId: preferredDriverId,
      );
      errorMessage = null;
      return bookingId;
    } on Exception catch (error) {
      errorMessage = userFacingErrorMessage(
        error,
        fallback: 'Unable to request this ride. Please try again.',
      );
      return null;
    } finally {
      isBookingLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _fareSettingsSubscription?.cancel();
    super.dispose();
  }
}
