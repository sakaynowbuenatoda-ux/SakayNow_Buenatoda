import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../controllers/quick_destinations_controller.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../models/ride_location.dart';
import '../../services/google_places_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/maps/location_pin_picker_sheet.dart';
import '../../widgets/maps/map_text_styles.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/passenger_widgets/passenger_booking_hero_card.dart';
import '../../widgets/passenger_widgets/passenger_quick_destinations_section.dart';
import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/ride_status_strip.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../rides/ride_monitoring_page.dart';
import 'passenger_data.dart';
import 'passenger_book_ride_page.dart';
import 'passenger_quick_destinations_page.dart';

class PassengerHomepage extends StatefulWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final bool isVerified;

  const PassengerHomepage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.isVerified,
  });

  @override
  State<PassengerHomepage> createState() => _PassengerHomepageState();
}

class _PassengerHomepageState extends State<PassengerHomepage> {
  late final QuickDestinationsController _quickDestinationsController;
  final GooglePlacesService _placesService = GooglePlacesService();
  final LocationService _locationService = const LocationService();

  @override
  void initState() {
    super.initState();
    _quickDestinationsController = QuickDestinationsController(
      userId: widget.userId,
    )..load();
  }

  @override
  void dispose() {
    _quickDestinationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Welcome back, ${widget.firstName}',
            subtitle:
                'Book faster with saved places, fair fares, and verified drivers.',
            icon: Icons.waving_hand_rounded,
            accentColor: PassengerUi.primary,
            dense: true,
          ),
          SizedBox(height: 16),
          StreamBuilder<Ride?>(
            stream: RideTrackingService().watchPassengerActiveRide(
              widget.userId,
            ),
            builder: (context, snapshot) {
              final ride = snapshot.data;
              if (ride != null) {
                return PassengerBookingHeroCard(
                  actionLabel: 'Continue Monitoring',
                  actionIcon: Icons.near_me_rounded,
                  content: _RideMonitoringPreview(ride: ride),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RideMonitoringPage(
                        bookingId: ride.bookingId,
                        userId: widget.userId,
                        viewerRole: RideViewerRole.passenger,
                      ),
                    ),
                  ),
                );
              }

              return PassengerBookingHeroCard(
                content: const _LiveBookingMapPreview(),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PassengerBookRidePage(passengerId: widget.userId),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 24),
          AnimatedBuilder(
            animation: _quickDestinationsController,
            builder: (context, _) {
              return PassengerQuickDestinationsSection(
                destinations: _quickDestinationsController.destinations,
                onSeeAllTap: _openQuickDestinationsPage,
                onDestinationTap: _handleQuickDestinationTap,
              );
            },
          ),
          SizedBox(height: 24),
          PassengerRecentTripsSection(
            passengerId: widget.userId,
            limit: 2,
            onViewAllTap: () => _showSnackBar(
              context,
              'Open the History tab to see all trips.',
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleQuickDestinationTap(
    PassengerQuickDestination destination,
  ) async {
    if (!destination.hasCoordinates) {
      await _setQuickDestinationLocation(destination);
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerBookRidePage(
          passengerId: widget.userId,
          initialDropoffDestination: destination,
        ),
      ),
    );
  }

  Future<void> _setQuickDestinationLocation(
    PassengerQuickDestination destination,
  ) async {
    final pickerTarget = await _quickDestinationPickerTarget(destination);
    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<LocationPinPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPinPickerSheet(
        title: 'Set ${destination.label}',
        actionLabel: 'Save Location',
        initialTarget: pickerTarget.location,
        accentColor: destination.accentColor,
        myLocationEnabled: pickerTarget.usesCurrentLocation,
      ),
    );

    if (selected == null) {
      return;
    }

    final location = await _locationFromPin(selected);
    await _quickDestinationsController.upsert(
      destination.copyWith(
        address: _locationDisplayText(location),
        latitude: location.latitude,
        longitude: location.longitude,
      ),
    );
  }

  Future<RideLocation> _locationFromPin(LocationPinPickResult selected) async {
    final googlePlace = selected.googlePlace;
    if (googlePlace != null) {
      return googlePlace;
    }

    final location = selected.location;
    try {
      final knownPlace = await _placesService.nearestKnownPlace(location);
      if (knownPlace != null) {
        return knownPlace;
      }
      final address = await _placesService.reverseGeocode(location);
      return RideLocation(
        address: address,
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } on Exception {
      return RideLocation(
        address:
            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }
  }

  Future<_PickerTarget> _quickDestinationPickerTarget(
    PassengerQuickDestination destination,
  ) async {
    if (destination.hasCoordinates) {
      return _PickerTarget(
        location: LatLng(destination.latitude!, destination.longitude!),
        usesCurrentLocation: false,
      );
    }

    try {
      final position = await _locationService.getCurrentPosition();
      return _PickerTarget(
        location: LatLng(position.latitude, position.longitude),
        usesCurrentLocation: true,
      );
    } on Exception {
      return const _PickerTarget(
        location: MapConfig.buenavistaCenter,
        usesCurrentLocation: false,
      );
    }
  }

  String _locationDisplayText(RideLocation location) {
    return location.displayLabel;
  }

  void _openQuickDestinationsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerQuickDestinationsPage(
          controller: _quickDestinationsController,
        ),
      ),
    );
  }
}

class _PickerTarget {
  final LatLng location;
  final bool usesCurrentLocation;

  const _PickerTarget({
    required this.location,
    required this.usesCurrentLocation,
  });
}

class _LiveBookingMapPreview extends StatefulWidget {
  const _LiveBookingMapPreview();

  @override
  State<_LiveBookingMapPreview> createState() => _LiveBookingMapPreviewState();
}

class _LiveBookingMapPreviewState extends State<_LiveBookingMapPreview> {
  late final Future<LatLng> _currentLocationFuture;
  final LocationService _locationService = const LocationService();

  @override
  void initState() {
    super.initState();
    _currentLocationFuture = _loadCurrentLocation();
  }

  Future<LatLng> _loadCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatLng>(
      future: _currentLocationFuture,
      builder: (context, snapshot) {
        final location = snapshot.data ?? MapConfig.buenavistaCenter;
        final hasLocation = snapshot.hasData;

        return ClipRRect(
          borderRadius: PassengerUi.cardRadius,
          child: SizedBox(
            height: PassengerUi.isCompactWidth(context) ? 210 : 230,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: SakayGoogleMap(
                    initialCameraTarget: location,
                    markers: hasLocation
                        ? <Marker>{
                            Marker(
                              markerId: const MarkerId(
                                'current_location_preview',
                              ),
                              position: location,
                              infoWindow: const InfoWindow(
                                title: 'Current location',
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure,
                              ),
                            ),
                          }
                        : const <Marker>{},
                    myLocationEnabled: hasLocation,
                    autoMoveCamera: true,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _MapOverlayPill(
                    icon: hasLocation
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    text: hasLocation
                        ? 'Live map'
                        : snapshot.hasError
                        ? 'Location unavailable'
                        : 'Finding location',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RideMonitoringPreview extends StatelessWidget {
  final Ride ride;

  const _RideMonitoringPreview({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: PassengerUi.accentBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.route_rounded, color: PassengerUi.accentBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Ride Monitoring', style: MapTextStyles.title),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleFor(ride),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MapTextStyles.body,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: PassengerUi.cardRadius,
          child: SizedBox(
            height: 180,
            child: SakayGoogleMap(
              initialCameraTarget: _initialTarget(ride),
              bounds: _boundsFor(ride),
              markers: _markersFor(ride),
              polylines: _polylinesFor(ride),
              autoMoveCamera: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        RideStatusStripForRide(ride: ride),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _RideMetric(
                icon: Icons.access_time_rounded,
                label: 'ETA',
                value: ride.etaLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RideMetric(
                icon: Icons.route_rounded,
                label: 'Distance',
                value: ride.distanceLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _subtitleFor(Ride ride) {
    final destination = ride.dropoffLocation.displayLabel;
    return '${ride.status.label} to $destination';
  }

  static LatLng _initialTarget(Ride ride) {
    final bounds = _boundsFor(ride);
    if (bounds != null) {
      return LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );
    }

    return ride.driverLocation?.latLng ??
        ride.pickupLocation.latLng ??
        ride.dropoffLocation.latLng ??
        MapConfig.buenavistaCenter;
  }

  static Set<Marker> _markersFor(Ride ride) {
    final markers = <Marker>{};
    final pickup = ride.pickupLocation.latLng;
    final dropoff = ride.dropoffLocation.latLng;
    final driver = ride.driverLocation?.latLng;

    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('active_pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('active_dropoff'),
          position: dropoff,
          infoWindow: const InfoWindow(title: 'Drop-off'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('active_driver'),
          position: driver,
          infoWindow: const InfoWindow(title: 'Driver'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    return markers;
  }

  static Set<Polyline> _polylinesFor(Ride ride) {
    final pickup = ride.pickupLocation.latLng;
    final dropoff = ride.dropoffLocation.latLng;
    final driver = ride.driverLocation?.latLng;
    final points = <LatLng>[
      if (ride.status == RideStatus.searching && pickup != null) pickup,
      ?driver,
      ?pickup,
      if (ride.status == RideStatus.inProgress && dropoff != null) dropoff,
      if (driver == null && pickup != null && dropoff != null) dropoff,
    ];

    if (points.length < 2) {
      return <Polyline>{};
    }

    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('active_ride_route'),
        points: points,
        color: PassengerUi.accentBlue,
        width: 5,
      ),
    };
  }

  static LatLngBounds? _boundsFor(Ride ride) {
    final points = <LatLng>[
      if (ride.driverLocation != null) ride.driverLocation!.latLng,
      if (ride.pickupLocation.latLng != null) ride.pickupLocation.latLng!,
      if (ride.dropoffLocation.latLng != null &&
          (ride.status == RideStatus.searching ||
              ride.status == RideStatus.inProgress))
        ride.dropoffLocation.latLng!,
    ];

    if (points.length < 2) {
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
}

class _MapOverlayPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MapOverlayPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PassengerUi.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PassengerUi.border),
          boxShadow: PassengerUi.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: PassengerUi.accentBlue),
              const SizedBox(width: 6),
              Text(text, style: MapTextStyles.value.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RideMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: PassengerUi.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: MapTextStyles.body.copyWith(fontSize: 12)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.value.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
