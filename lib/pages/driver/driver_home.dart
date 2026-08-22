import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../core/preferences/app_preferences_controller.dart';
import '../../models/ride_driver_location.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../services/booking_action_cooldown_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/action_cooldown_notice.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/driver_rating_leaderboard_panel.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/maps/map_type_toggle.dart';
import '../../widgets/maps/ride_location_preview_dialog.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/reviews/review_dialogs.dart';
import '../../widgets/reports/report_user_sheet.dart';
import '../../widgets/time_ago_text.dart';
import '../../widgets/trip_history_sort.dart';
import '../driver_ratings/driver_leaderboard_page.dart';
import '../profile/passenger_profile.dart';
import '../rides/ride_monitoring_page.dart';
import 'widgets/driver_ride_request_card.dart';

class DriverHomePage extends StatelessWidget {
  final String userId;
  final String firstName;
  final bool isActive;
  final bool hasInternetConnection;
  final bool isVerified;
  final bool canReceiveBookings;
  final String? profileImageUrl;
  final int notificationUnreadCount;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onBrandTap;
  final VoidCallback? onProfileTap;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenHistory;

  const DriverHomePage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.isActive,
    this.hasInternetConnection = true,
    required this.isVerified,
    this.canReceiveBookings = false,
    this.profileImageUrl,
    this.notificationUnreadCount = 0,
    required this.onNotificationsTap,
    this.onBrandTap,
    this.onProfileTap,
    required this.onOpenQueue,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerHomeSplitLayout(
      map: DriverLiveRequestMapCard(
        driverId: userId,
        expanded: true,
        showRequests: isActive,
      ),
      header: HomeMapHeader(
        firstName: firstName,
        profileImageUrl: profileImageUrl,
        greeting: firstName.trim().isEmpty
            ? 'Welcome'
            : 'Welcome, ${firstName.trim()}',
        isDriver: true,
        showVerifiedBadge: isVerified,
        notificationUnreadCount: notificationUnreadCount,
        onLeaderboardTap: () => _openDriverLeaderboard(context),
        onNotificationsTap: onNotificationsTap,
        onBrandTap: onBrandTap,
        onProfileTap: onProfileTap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DriverStatusHeroCard(
            isActive: isActive,
            hasInternetConnection: hasInternetConnection,
          ),
          DriverActiveRideShortcut(driverId: userId),
          const SizedBox(height: 20),
          PassengerSectionHeader(
            title: 'Incoming Requests',
            actionLabel: 'Open queue',
            onActionTap: onOpenQueue,
          ),
          const SizedBox(height: 12),
          _LiveIncomingRequestsPreview(
            driverId: userId,
            isVerified: isVerified,
            canReceiveBookings: canReceiveBookings,
            isActive: isActive,
          ),
          const SizedBox(height: 20),
          PassengerSectionHeader(
            title: 'Recent Trips',
            actionLabel: 'View all',
            onActionTap: onOpenHistory,
          ),
          const SizedBox(height: 12),
          DriverRecentTripsSection(driverId: userId, limit: 3),
          const SizedBox(height: 20),
          DriverRatingLeaderboardPanel(
            limit: 20,
            actionLabel: 'See Top 20',
            highlightDriverId: userId,
            compactPodium: true,
            onActionTap: () => _openDriverLeaderboard(context),
          ),
        ],
      ),
    );
  }

  void _openDriverLeaderboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverLeaderboardPage(highlightDriverId: userId),
      ),
    );
  }
}

class DriverActiveRideShortcut extends StatelessWidget {
  final String driverId;
  final RideTrackingService rideTrackingService;

  DriverActiveRideShortcut({
    super.key,
    required this.driverId,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ride>>(
      stream: rideTrackingService.watchDriverActiveRides(driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: AppSkeletonCard(showAvatar: true, lineCount: 2),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PassengerSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    color: PassengerUi.highlightAmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unable to check active rides.',
                      style: PassengerUi.bodyText,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final activeRides = _sortedActiveRides(snapshot.data ?? const <Ride>[]);
        if (activeRides.isEmpty) {
          return const SizedBox.shrink();
        }

        final ride = activeRides.first;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PassengerSurfaceCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PassengerUi.successBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        color: PassengerUi.successText,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            activeRides.length == 1
                                ? 'Active ride'
                                : '${activeRides.length} active rides',
                            style: PassengerUi.cardTitle.copyWith(
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _routeLabel(ride),
                            style: PassengerUi.bodyText.copyWith(
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PassengerStatusChip(
                      label: ride.status.label,
                      textColor: PassengerUi.successText,
                      backgroundColor: PassengerUi.successBackground,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.access_time_rounded,
                      size: 17,
                      color: PassengerUi.accentBlue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TimeAgoText(
                        dateTime: ride.updatedAt ?? ride.createdAt,
                        style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _reportDriverHomePassenger(
                        context: context,
                        rideTrackingService: rideTrackingService,
                        bookingId: ride.bookingId,
                        driverId: driverId,
                        passengerId: ride.passengerId,
                        passengerName: 'Passenger',
                      ),
                      icon: Icon(
                        Icons.report_gmailerrorred_rounded,
                        size: 16,
                        color: PassengerUi.primary,
                      ),
                      label: Text(
                        'Report',
                        style: TextStyle(color: PassengerUi.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: PassengerUi.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openRideMonitoring(context, ride),
                      icon: const Icon(Icons.near_me_rounded, size: 18),
                      label: const Text('Ride Monitoring'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Ride> _sortedActiveRides(List<Ride> rides) {
    final activeRides = rides
        .where((ride) => !ride.status.isTerminal)
        .toList(growable: false);
    activeRides.sort(
      (a, b) => _latestActivity(b).compareTo(_latestActivity(a)),
    );
    return activeRides;
  }

  DateTime _latestActivity(Ride ride) {
    return ride.updatedAt ??
        ride.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _routeLabel(Ride ride) {
    final pickup = ride.pickupLocation.publicDisplayLabel;
    final dropoff = ride.dropoffLocation.publicDisplayLabel;
    return '$pickup to $dropoff';
  }

  void _openRideMonitoring(BuildContext context, Ride ride) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideMonitoringPage(
          bookingId: ride.bookingId,
          userId: driverId,
          viewerRole: RideViewerRole.driver,
        ),
      ),
    );
  }
}

class DriverStatusHeroCard extends StatelessWidget {
  final bool isActive;
  final bool hasInternetConnection;

  const DriverStatusHeroCard({
    super.key,
    required this.isActive,
    this.hasInternetConnection = true,
  });

  @override
  Widget build(BuildContext context) {
    final showActiveState = hasInternetConnection && isActive;

    return AnimatedContainer(
      key: const Key('driver-status-card'),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: PassengerUi.cardRadius,
        border: Border.all(
          color: showActiveState ? PassengerUi.successText : PassengerUi.border,
          width: showActiveState ? 2 : 1,
        ),
        boxShadow: PassengerUi.cardShadow,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: !hasInternetConnection
            ? const _NoInternetDriverStatus(key: ValueKey('no-internet'))
            : isActive
            ? const _ActiveDriverStatus(key: ValueKey('active'))
            : const _OfflineDriverStatus(key: ValueKey('offline')),
      ),
    );
  }
}

class _OfflineDriverStatus extends StatelessWidget {
  const _OfflineDriverStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.power_settings_new_rounded,
          key: const Key('driver-offline-icon'),
          size: 34,
          color: PassengerUi.isDarkMode ? Colors.white : Colors.black,
        ),
        const SizedBox(height: 12),
        Text(
          'You are currently offline',
          textAlign: TextAlign.center,
          style: PassengerUi.cardTitle.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Go active to receive new bookings around Buenavista.',
          textAlign: TextAlign.center,
          style: PassengerUi.bodyText.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

class _ActiveDriverStatus extends StatelessWidget {
  const _ActiveDriverStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          'Active State',
          textAlign: TextAlign.center,
          style: PassengerUi.cardTitle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'You are visible to passengers and ready to accept requests.',
          textAlign: TextAlign.center,
          style: PassengerUi.bodyText.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

class _NoInternetDriverStatus extends StatelessWidget {
  const _NoInternetDriverStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No internet',
        textAlign: TextAlign.center,
        style: PassengerUi.cardTitle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DriverLiveRequestMapCard extends StatefulWidget {
  final String driverId;
  final bool expanded;
  final bool showRequests;

  const DriverLiveRequestMapCard({
    super.key,
    required this.driverId,
    this.expanded = false,
    this.showRequests = true,
  });

  @override
  State<DriverLiveRequestMapCard> createState() =>
      _DriverLiveRequestMapCardState();
}

class _DriverLiveRequestMapCardState extends State<DriverLiveRequestMapCard> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final LocationService _locationService = const LocationService();
  final _passengerProfileFutures = <String, Future<PassengerReviewProfile?>>{};
  late final Future<LatLng> _currentLocationFuture;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _currentLocationFuture = _loadCurrentLocation();
  }

  Future<LatLng> _loadCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _centerOnCurrentLocation(LatLng location) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.animateCamera(CameraUpdate.newLatLng(location));
    } on Exception {
      // The native map can be unavailable briefly during a platform rebuild.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapContent = StreamBuilder<RideDriverLocation?>(
      stream: _rideTrackingService.watchDriverLocation(widget.driverId),
      builder: (context, locationSnapshot) {
        return FutureBuilder<LatLng>(
          future: _currentLocationFuture,
          builder: (context, fallbackSnapshot) {
            final driverLocation = locationSnapshot.data?.latLng;
            final fallbackLocation =
                fallbackSnapshot.data ?? MapConfig.buenavistaCenter;
            final mapCenter = driverLocation ?? fallbackLocation;

            return StreamBuilder<List<Ride>>(
              stream: widget.showRequests
                  ? _rideTrackingService.watchOpenBookings(
                      driverId: widget.driverId,
                    )
                  : null,
              builder: (context, rideSnapshot) {
                final rides = rideSnapshot.data ?? const <Ride>[];
                final visibleRides = rides
                    .where((ride) => ride.pickupLocation.latLng != null)
                    .toList(growable: false);
                _prunePassengerProfileFutures(visibleRides);
                final passengerProfilesFuture = _passengerProfilesFor(
                  visibleRides,
                );
                final markers = _buildMarkers(
                  driverLocation: mapCenter,
                  rides: visibleRides,
                );
                final bounds = _boundsFor([
                  mapCenter,
                  ...visibleRides
                      .map((ride) => ride.pickupLocation.latLng)
                      .nonNulls,
                ]);

                Widget buildMapViewport({
                  required double? controlsTop,
                  double cameraVerticalOffset = 0,
                }) {
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      FutureBuilder<Map<String, PassengerReviewProfile?>>(
                        future: passengerProfilesFuture,
                        builder: (context, profileSnapshot) {
                          final passengerProfiles =
                              profileSnapshot.data ??
                              <String, PassengerReviewProfile?>{};

                          return AnimatedBuilder(
                            animation: AppPreferencesController.instance,
                            builder: (context, _) {
                              return SakayGoogleMap(
                                initialCameraTarget: mapCenter,
                                bounds: bounds,
                                markers: markers,
                                profilePins: _passengerProfilePins(
                                  visibleRides,
                                  passengerProfiles,
                                ),
                                mapType: AppPreferencesController
                                    .instance
                                    .googleMapType,
                                myLocationEnabled: driverLocation != null,
                                myLocationButtonEnabled:
                                    !widget.expanded && driverLocation != null,
                                cameraTargetOffset: Offset(
                                  0,
                                  cameraVerticalOffset,
                                ),
                                onMapCreated: widget.expanded
                                    ? (controller) =>
                                          _mapController = controller
                                    : null,
                                autoMoveCamera: true,
                              );
                            },
                          );
                        },
                      ),
                      Positioned(
                        top: controlsTop ?? 10,
                        right: widget.expanded ? 8 : 10,
                        child: Column(
                          key: widget.expanded
                              ? const Key('driver-home-map-controls')
                              : null,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            const MapTypeToggle(),
                            if (widget.expanded &&
                                driverLocation != null) ...<Widget>[
                              const SizedBox(height: 8),
                              MapCurrentLocationButton(
                                key: const Key(
                                  'driver-home-current-location-button',
                                ),
                                onPressed: () =>
                                    _centerOnCurrentLocation(mapCenter),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: widget.expanded ? 8 : 10,
                        right: 112,
                        top: controlsTop ?? 10,
                        child: _DriverMapStatusPill(
                          requestCount: rides.length,
                          passengerCount: _uniquePassengerCount(rides),
                          hasDriverLocation: driverLocation != null,
                          isLoading:
                              locationSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              (widget.showRequests &&
                                  rideSnapshot.connectionState ==
                                      ConnectionState.waiting),
                          isOnline: widget.showRequests,
                        ),
                      ),
                    ],
                  );
                }

                if (widget.expanded) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final controlsTop =
                          MediaQuery.paddingOf(context).top +
                          (PassengerUi.isCompactWidth(context) ? 88 : 96);
                      return buildMapViewport(
                        controlsTop: controlsTop,
                        cameraVerticalOffset: constraints.maxHeight * 0.16,
                      );
                    },
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: PassengerUi.cardRadius,
                      child: SizedBox(
                        height: PassengerUi.isCompactWidth(context) ? 260 : 300,
                        child: buildMapViewport(controlsTop: null),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.radio_button_checked_rounded,
                          size: 16,
                          color: PassengerUi.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            visibleRides.isEmpty
                                ? 'Online. Passenger requests will appear on the map.'
                                : '${visibleRides.length} passenger pickup location(s) nearby.',
                            style: PassengerUi.bodyText.copyWith(
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (widget.expanded) {
      return mapContent;
    }

    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(10),
      child: mapContent,
    );
  }

  Future<Map<String, PassengerReviewProfile?>> _passengerProfilesFor(
    List<Ride> rides,
  ) async {
    final passengerIds = rides
        .map((ride) => ride.passengerId.trim())
        .where((passengerId) => passengerId.isNotEmpty)
        .toSet();

    if (passengerIds.isEmpty) {
      return <String, PassengerReviewProfile?>{};
    }

    final entries = await Future.wait(
      passengerIds.map((passengerId) async {
        final profile = await _passengerProfileFor(passengerId);
        return MapEntry<String, PassengerReviewProfile?>(passengerId, profile);
      }),
    );

    return Map<String, PassengerReviewProfile?>.fromEntries(entries);
  }

  Future<PassengerReviewProfile?> _passengerProfileFor(String passengerId) {
    return _passengerProfileFutures.putIfAbsent(passengerId, () async {
      try {
        return await _rideTrackingService.loadPassengerProfile(passengerId);
      } on Exception {
        return null;
      }
    });
  }

  void _prunePassengerProfileFutures(List<Ride> rides) {
    final passengerIds = rides
        .map((ride) => ride.passengerId.trim())
        .where((passengerId) => passengerId.isNotEmpty)
        .toSet();

    _passengerProfileFutures.removeWhere(
      (passengerId, _) => !passengerIds.contains(passengerId),
    );
  }

  Set<Marker> _buildMarkers({
    required LatLng driverLocation,
    required List<Ride> rides,
  }) {
    return <Marker>{
      Marker(
        markerId: const MarkerId('driver_current_location'),
        position: driverLocation,
        infoWindow: const InfoWindow(title: 'Your current location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      ...rides.map((ride) {
        final pickup = ride.pickupLocation.latLng!;
        final isPreferred = ride.preferredDriverId == widget.driverId;

        return Marker(
          markerId: MarkerId('passenger_pickup_${ride.bookingId}'),
          position: pickup,
          infoWindow: InfoWindow(
            title: isPreferred ? 'Requested you' : 'Open request',
            snippet: ride.pickupLocation.publicDisplayLabel,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isPreferred ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRed,
          ),
        );
      }),
    };
  }

  List<MapProfilePin> _passengerProfilePins(
    List<Ride> rides,
    Map<String, PassengerReviewProfile?> passengerProfiles,
  ) {
    return rides
        .map((ride) {
          final passenger = passengerProfiles[ride.passengerId.trim()];
          final isPreferred = ride.preferredDriverId == widget.driverId;
          final requestLabel = isPreferred ? 'Requested you' : 'Open request';
          final pickupLabel = ride.pickupLocation.publicDisplayLabel.trim();
          final detail = pickupLabel.isEmpty
              ? requestLabel
              : '$requestLabel - $pickupLabel';

          return MapProfilePin(
            markerId: MarkerId('passenger_pickup_${ride.bookingId}'),
            name: passenger?.fullName ?? 'Passenger',
            imageUrl: passenger?.profileImageUrl,
            detail: detail,
            accentColor: isPreferred
                ? PassengerUi.accentBlue
                : PassengerUi.secondary,
          );
        })
        .toList(growable: false);
  }

  int _uniquePassengerCount(List<Ride> rides) {
    return rides
        .map((ride) => ride.passengerId)
        .where((passengerId) => passengerId.trim().isNotEmpty)
        .toSet()
        .length;
  }

  LatLngBounds? _boundsFor(List<LatLng> points) {
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

class _DriverMapStatusPill extends StatelessWidget {
  final int requestCount;
  final int passengerCount;
  final bool hasDriverLocation;
  final bool isLoading;
  final bool isOnline;

  const _DriverMapStatusPill({
    required this.requestCount,
    required this.passengerCount,
    required this.hasDriverLocation,
    required this.isLoading,
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    final onlineText = isLoading
        ? 'Syncing'
        : isOnline
        ? 'Online'
        : 'Offline';
    final countText =
        '$passengerCount passenger${passengerCount == 1 ? '' : 's'}';

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PassengerUi.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PassengerUi.border),
          boxShadow: PassengerUi.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                hasDriverLocation
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                size: 15,
                color: PassengerUi.accentBlue,
              ),
              const SizedBox(width: 6),
              Text(
                onlineText,
                style: PassengerUi.valueText.copyWith(fontSize: 12),
              ),
              if (isOnline) ...<Widget>[
                const SizedBox(width: 8),
                Container(width: 1, height: 14, color: PassengerUi.border),
                const SizedBox(width: 8),
                Icon(
                  Icons.groups_2_rounded,
                  size: 15,
                  color: PassengerUi.secondary,
                ),
                const SizedBox(width: 5),
                Text(
                  countText,
                  style: PassengerUi.valueText.copyWith(
                    fontSize: 12,
                    color: PassengerUi.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveIncomingRequestsPreview extends StatefulWidget {
  final String driverId;
  final bool isVerified;
  final bool canReceiveBookings;
  final bool isActive;

  const _LiveIncomingRequestsPreview({
    required this.driverId,
    required this.isVerified,
    required this.canReceiveBookings,
    required this.isActive,
  });

  @override
  State<_LiveIncomingRequestsPreview> createState() =>
      _LiveIncomingRequestsPreviewState();
}

class _LiveIncomingRequestsPreviewState
    extends State<_LiveIncomingRequestsPreview> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final BookingActionCooldownService _cooldownService =
      BookingActionCooldownService.instance;
  String? _acceptingBookingId;
  String? _decliningBookingId;

  @override
  void initState() {
    super.initState();
    _cooldownService.addListener(_handleCooldownChanged);
    unawaited(
      _cooldownService.loadForUser(
        userId: widget.driverId,
        targets: const <BookingActionCooldownTarget>[
          BookingActionCooldownTarget.driverAccept,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cooldownService.removeListener(_handleCooldownChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVerified) {
      return const PassengerEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'Pending verification',
        description:
            'Admin verification is required before accepting passenger bookings.',
      );
    }

    if (!widget.canReceiveBookings) {
      return const PassengerEmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Documents expired',
        description:
            'Your account remains verified. Submit a current Driver\'s License or OR/CR before receiving new bookings.',
      );
    }

    if (!widget.isActive) {
      return const PassengerEmptyState(
        icon: Icons.power_settings_new_rounded,
        title: 'Go active to receive requests',
        description:
            'Turn on driver availability when you are ready to accept nearby bookings.',
      );
    }

    return StreamBuilder<List<Ride>>(
      stream: _rideTrackingService.watchOpenBookings(driverId: widget.driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 3, padding: EdgeInsets.zero);
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load requests',
            description:
                'Passenger requests could not be loaded. Please try again.',
          );
        }

        final rides = snapshot.data ?? <Ride>[];
        final acceptCooldownRemaining = _acceptCooldownRemaining;
        if (rides.isEmpty) {
          return const PassengerEmptyState(
            icon: Icons.route_rounded,
            title: 'No incoming requests',
            description:
                'New passenger bookings will appear here in real time.',
          );
        }

        final previewRides = rides.take(2).toList(growable: false);
        return Column(
          children: <Widget>[
            if (acceptCooldownRemaining > Duration.zero) ...<Widget>[
              ActionCooldownNotice(
                message:
                    'You can accept another request in ${BookingActionCooldownService.formatRemaining(acceptCooldownRemaining)}.',
              ),
              const SizedBox(height: 12),
            ],
            ...previewRides.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == previewRides.length - 1 ? 0 : 12,
                ),
                child: DriverRideRequestCard(
                  ride: entry.value,
                  driverId: widget.driverId,
                  isAccepting: _acceptingBookingId == entry.value.bookingId,
                  isDeclining: _decliningBookingId == entry.value.bookingId,
                  acceptCooldownRemaining: acceptCooldownRemaining,
                  rideTrackingService: _rideTrackingService,
                  onAccept: () => _acceptRide(entry.value),
                  onDecline: () => _declineRide(entry.value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Duration get _acceptCooldownRemaining {
    return _cooldownService.remainingFor(
      userId: widget.driverId,
      target: BookingActionCooldownTarget.driverAccept,
    );
  }

  void _handleCooldownChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _acceptRide(Ride ride) async {
    if (!widget.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin verification is required before accepting bookings.',
          ),
        ),
      );
      return;
    }
    if (!widget.canReceiveBookings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account remains verified, but current driver documents are required before accepting bookings.',
          ),
        ),
      );
      return;
    }

    final acceptCooldownRemaining = _acceptCooldownRemaining;
    if (acceptCooldownRemaining > Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait ${BookingActionCooldownService.formatRemaining(acceptCooldownRemaining)} before accepting another request.',
          ),
        ),
      );
      return;
    }

    setState(() => _acceptingBookingId = ride.bookingId);

    try {
      await _rideTrackingService.acceptBooking(
        bookingId: ride.bookingId,
        driverId: widget.driverId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideMonitoringPage(
            bookingId: ride.bookingId,
            userId: widget.driverId,
            viewerRole: RideViewerRole.driver,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to accept this request. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _acceptingBookingId = null);
      }
    }
  }

  Future<void> _declineRide(Ride ride) async {
    if (!widget.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin verification is required before declining bookings.',
          ),
        ),
      );
      return;
    }
    if (!widget.canReceiveBookings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account remains verified, but current driver documents are required before managing booking requests.',
          ),
        ),
      );
      return;
    }

    setState(() => _decliningBookingId = ride.bookingId);

    try {
      await _rideTrackingService.declineBooking(
        bookingId: ride.bookingId,
        driverId: widget.driverId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request declined and kept open for other drivers.'),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to decline this request. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _decliningBookingId = null);
      }
    }
  }
}

class DriverRecentTripsSection extends StatelessWidget {
  final String driverId;
  final int? limit;
  final TripHistorySortOption sortOption;

  const DriverRecentTripsSection({
    super.key,
    required this.driverId,
    this.limit = 8,
    this.sortOption = TripHistorySortOption.newest,
  });

  @override
  Widget build(BuildContext context) {
    final rideTrackingService = RideTrackingService();

    return StreamBuilder<List<DriverRecentTrip>>(
      stream: rideTrackingService.watchDriverRecentTrips(
        driverId,
        limit: limit,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppSkeletonCard(showAvatar: true, height: 112);
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load recent trips',
            description: 'Recent trips could not be loaded. Please try again.',
          );
        }

        final trips = sortTripHistory<DriverRecentTrip>(
          trips: snapshot.data ?? const <DriverRecentTrip>[],
          rideOf: (trip) => trip.ride,
          option: sortOption,
        );
        if (trips.isEmpty) {
          return const PassengerEmptyState(
            icon: Icons.history_rounded,
            title: 'No recent trips',
            description: 'Completed and cancelled trips will appear here.',
          );
        }

        return Column(
          children: trips
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == trips.length - 1 ? 0 : 8,
                  ),
                  child: DriverRecentTripCard(
                    trip: entry.value,
                    driverId: driverId,
                    rideTrackingService: rideTrackingService,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DriverRecentTripCard extends StatelessWidget {
  final DriverRecentTrip trip;
  final String driverId;
  final RideTrackingService rideTrackingService;

  const DriverRecentTripCard({
    super.key,
    required this.trip,
    required this.driverId,
    required this.rideTrackingService,
  });

  @override
  Widget build(BuildContext context) {
    final ride = trip.ride;
    final passenger = trip.passenger;
    final rating = ride.driverPassengerReviewRating;
    final canReviewPassenger = ride.canDriverReviewPassenger;
    final canPreviewRoute =
        ride.pickupLocation.latLng != null &&
        ride.dropoffLocation.latLng != null;

    return PassengerSurfaceCard(
      key: ValueKey<String>('driver-trip-${ride.bookingId}'),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openPassengerProfile(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: <Widget>[
                        _PassengerAvatar(profile: passenger, size: 40),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      passenger.fullName,
                                      style: PassengerUi.cardTitle.copyWith(
                                        fontSize: 13.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (passenger.isVerified) ...[
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Verified passenger',
                                      child: Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: PassengerUi.accentBlue,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      passenger.roleLabel,
                                      style: PassengerUi.bodyText.copyWith(
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: PassengerUi.body,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TimeAgoText(
                                      dateTime:
                                          ride.updatedAt ?? ride.createdAt,
                                      style: PassengerUi.bodyText.copyWith(
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PassengerStatusChip(
                dense: true,
                label: ride.status.label,
                textColor: ride.status == RideStatus.completed
                    ? PassengerUi.successText
                    : PassengerUi.primary,
                backgroundColor: ride.status == RideStatus.completed
                    ? PassengerUi.successBackground
                    : PassengerUi.dangerSoft,
              ),
            ],
          ),
          const SizedBox(height: 7),
          _DriverHistoryRouteBlock(
            pickup: ride.pickupLocation.publicDisplayLabel,
            dropoff: ride.dropoffLocation.publicDisplayLabel,
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      ride.fareLabel ?? 'Fare pending',
                      style: PassengerUi.valueText.copyWith(fontSize: 11.5),
                    ),
                    if (ride.distanceLabel != 'Calculating')
                      Text(
                        ride.distanceLabel,
                        style: PassengerUi.bodyText.copyWith(fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (canPreviewRoute) ...<Widget>[
                    RideLocationPreviewButton(
                      pickupLocation: ride.pickupLocation,
                      dropoffLocation: ride.dropoffLocation,
                      route: ride.route,
                      dimension: 30,
                      iconSize: 16,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Tooltip(
                    message: 'Report passenger',
                    child: IconButton(
                      key: ValueKey<String>(
                        'driver-trip-report-${ride.bookingId}',
                      ),
                      onPressed: () => _reportDriverHomePassenger(
                        context: context,
                        rideTrackingService: rideTrackingService,
                        bookingId: ride.bookingId,
                        driverId: driverId,
                        passengerId: passenger.userId,
                        passengerName: passenger.fullName,
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: PassengerUi.primary,
                        backgroundColor: PassengerUi.dangerSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: PassengerUi.primary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.report_gmailerrorred_rounded,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: rating == null
                        ? canReviewPassenger
                              ? 'Rate passenger'
                              : 'Passenger rating unavailable'
                        : 'Rated $rating stars',
                    child: InkWell(
                      key: ValueKey<String>(
                        'driver-trip-review-${ride.bookingId}',
                      ),
                      borderRadius: BorderRadius.circular(8),
                      onTap: canReviewPassenger
                          ? () => _showRatingChoices(context)
                          : null,
                      child: Container(
                        height: 30,
                        constraints: const BoxConstraints(minWidth: 30),
                        padding: EdgeInsets.symmetric(
                          horizontal: rating == null ? 7 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: canReviewPassenger || rating != null
                              ? PassengerUi.warningSoft
                              : PassengerUi.mutedSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PassengerUi.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              rating == null
                                  ? canReviewPassenger
                                        ? Icons.star_border_rounded
                                        : Icons.block_rounded
                                  : Icons.star_rounded,
                              size: 16,
                              color: rating == null
                                  ? canReviewPassenger
                                        ? PassengerUi.highlightAmber
                                        : PassengerUi.body
                                  : PassengerUi.highlightAmber,
                            ),
                            if (rating != null) ...<Widget>[
                              const SizedBox(width: 2),
                              Text(
                                rating.toString(),
                                style: PassengerUi.valueText.copyWith(
                                  fontSize: 10.5,
                                  color: PassengerUi.highlightAmber,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingChoices(BuildContext context) async {
    final selectedRating = await showDriverPassengerRatingDialog(
      context,
      passengerName: trip.passenger.fullName,
      selectedRating: trip.ride.driverPassengerReviewRating,
    );

    if (selectedRating == null || !context.mounted) {
      return;
    }

    try {
      await rideTrackingService.saveDriverPassengerReview(
        bookingId: trip.ride.bookingId,
        driverId: driverId,
        passengerId: trip.passenger.userId,
        rating: selectedRating,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Passenger review saved.')));
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to save this review. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _openPassengerProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassengerProfilePage(
          passengerId: trip.passenger.userId,
          driverId: driverId,
          bookingId: trip.ride.bookingId,
        ),
      ),
    );
  }
}

class _DriverHistoryRouteBlock extends StatelessWidget {
  final String pickup;
  final String dropoff;

  const _DriverHistoryRouteBlock({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _DriverHistoryLocationLine(
          icon: Icons.my_location_rounded,
          iconColor: PassengerUi.secondary,
          label: 'Pickup',
          value: pickup,
        ),
        const SizedBox(height: 3),
        _DriverHistoryLocationLine(
          icon: Icons.location_on_rounded,
          iconColor: PassengerUi.primary,
          label: 'Drop-off',
          value: dropoff,
        ),
      ],
    );
  }
}

class _DriverHistoryLocationLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DriverHistoryLocationLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: PassengerUi.bodyText.copyWith(fontSize: 11.5, height: 1.2),
              children: <InlineSpan>[
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: PassengerUi.valueText.copyWith(
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PassengerAvatar extends StatelessWidget {
  final PassengerReviewProfile profile;
  final double size;

  const _PassengerAvatar({required this.profile, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.profileImageUrl;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: FirebaseStorageImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(profile.fullName),
              style: PassengerUi.valueText.copyWith(
                color: PassengerUi.accentBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'P';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

Future<void> _reportDriverHomePassenger({
  required BuildContext context,
  required RideTrackingService rideTrackingService,
  required String bookingId,
  required String driverId,
  required String passengerId,
  required String passengerName,
}) async {
  if (passengerId.trim().isEmpty || bookingId.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passenger details unavailable for reporting.'),
      ),
    );
    return;
  }
  final draft = await showUserReportSheet(
    context,
    title: 'Report $passengerName',
    reasons: const <String>[
      'Safety concern',
      'No-show or unreachable',
      'Incorrect pickup details',
      'Unprofessional behavior',
      'Payment concern',
      'Other',
    ],
  );
  if (draft == null) {
    return;
  }
  try {
    await rideTrackingService.reportPassenger(
      bookingId: bookingId,
      driverId: driverId,
      passengerId: passengerId,
      reason: draft.reason,
      details: draft.details,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted for admin review.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit report: $error')),
      );
    }
  }
}
