import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride_driver_location.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../services/location_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import '../rides/ride_monitoring_page.dart';
import 'widgets/driver_ride_request_card.dart';

class DriverHomePage extends StatelessWidget {
  final String userId;
  final String firstName;
  final bool isActive;
  final bool isVerified;
  final VoidCallback onOpenQueue;

  const DriverHomePage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.isActive,
    required this.isVerified,
    required this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Welcome, $firstName',
            subtitle:
                'Manage availability and respond to nearby booking requests.',
            icon: Icons.electric_rickshaw_rounded,
            accentColor: PassengerUi.secondary,
            dense: true,
          ),
          SizedBox(height: 16),
          isActive
              ? DriverLiveRequestMapCard(driverId: userId)
              : DriverStatusHeroCard(
                  firstName: firstName,
                  isActive: isActive,
                  isVerified: isVerified,
                ),
          DriverActiveRideShortcut(driverId: userId),
          SizedBox(height: 20),
          PassengerSectionHeader(
            title: 'Incoming Requests',
            actionLabel: 'Open queue',
            onActionTap: onOpenQueue,
          ),
          SizedBox(height: 12),
          _LiveIncomingRequestsPreview(
            driverId: userId,
            isVerified: isVerified,
          ),
          SizedBox(height: 20),
          PassengerSectionHeader(title: 'Recent Trips'),
          SizedBox(height: 12),
          DriverRecentTripsSection(driverId: userId),
        ],
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
          return const SizedBox.shrink();
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
    final pickup = ride.pickupLocation.displayLabel;
    final dropoff = ride.dropoffLocation.displayLabel;
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
  final String firstName;
  final bool isActive;
  final bool isVerified;

  const DriverStatusHeroCard({
    super.key,
    required this.firstName,
    required this.isActive,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PassengerUi.mutedSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.signal_wifi_off_rounded,
                  color: PassengerUi.accentBlue,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Current status',
                      style: PassengerUi.cardTitle.copyWith(fontSize: 16),
                    ),
                    SizedBox(height: 3),
                    Text(
                      isVerified
                          ? (isActive
                                ? 'You are visible to passengers and ready to accept requests.'
                                : 'Go active to receive new bookings around Buenavista.')
                          : 'Your account is still pending admin verification, but you can already explore the driver workspace.',
                      style: PassengerUi.bodyText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          PassengerStatusChip(
            label: isVerified
                ? (isActive ? 'Active for bookings' : 'Currently offline')
                : 'Pending verification',
            textColor: isVerified
                ? (isActive ? PassengerUi.successText : PassengerUi.primary)
                : PassengerUi.highlightAmber,
            backgroundColor: isVerified
                ? (isActive
                      ? PassengerUi.successBackground
                      : PassengerUi.dangerSoft)
                : PassengerUi.warningSoft,
          ),
        ],
      ),
    );
  }
}

class DriverLiveRequestMapCard extends StatefulWidget {
  final String driverId;

  const DriverLiveRequestMapCard({super.key, required this.driverId});

  @override
  State<DriverLiveRequestMapCard> createState() =>
      _DriverLiveRequestMapCardState();
}

class _DriverLiveRequestMapCardState extends State<DriverLiveRequestMapCard> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final LocationService _locationService = const LocationService();
  late final Future<LatLng> _currentLocationFuture;

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
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(10),
      child: StreamBuilder<RideDriverLocation?>(
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
                stream: _rideTrackingService.watchOpenBookings(
                  driverId: widget.driverId,
                ),
                builder: (context, rideSnapshot) {
                  final rides = rideSnapshot.data ?? const <Ride>[];
                  final visibleRides = rides
                      .where((ride) => ride.pickupLocation.latLng != null)
                      .toList(growable: false);
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: PassengerUi.cardRadius,
                        child: SizedBox(
                          height: PassengerUi.isCompactWidth(context)
                              ? 260
                              : 300,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: SakayGoogleMap(
                                  initialCameraTarget: mapCenter,
                                  bounds: bounds,
                                  markers: markers,
                                  myLocationEnabled: driverLocation != null,
                                  autoMoveCamera: true,
                                ),
                              ),
                              Positioned(
                                left: 10,
                                right: 10,
                                top: 10,
                                child: _DriverMapStatusPill(
                                  requestCount: rides.length,
                                  passengerCount: _uniquePassengerCount(rides),
                                  hasDriverLocation: driverLocation != null,
                                  isLoading:
                                      locationSnapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      rideSnapshot.connectionState ==
                                          ConnectionState.waiting,
                                ),
                              ),
                            ],
                          ),
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
      ),
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
            snippet: ride.pickupLocation.displayLabel,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isPreferred ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRed,
          ),
        );
      }),
    };
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

  const _DriverMapStatusPill({
    required this.requestCount,
    required this.passengerCount,
    required this.hasDriverLocation,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final onlineText = isLoading ? 'Syncing' : 'Online';
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
          ),
        ),
      ),
    );
  }
}

class _LiveIncomingRequestsPreview extends StatefulWidget {
  final String driverId;
  final bool isVerified;

  const _LiveIncomingRequestsPreview({
    required this.driverId,
    required this.isVerified,
  });

  @override
  State<_LiveIncomingRequestsPreview> createState() =>
      _LiveIncomingRequestsPreviewState();
}

class _LiveIncomingRequestsPreviewState
    extends State<_LiveIncomingRequestsPreview> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  String? _acceptingBookingId;
  String? _decliningBookingId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ride>>(
      stream: _rideTrackingService.watchOpenBookings(driverId: widget.driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load requests',
            description: snapshot.error.toString(),
          );
        }

        final rides = snapshot.data ?? <Ride>[];
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
          children: previewRides
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == previewRides.length - 1 ? 0 : 12,
                  ),
                  child: DriverRideRequestCard(
                    ride: entry.value,
                    isAccepting: _acceptingBookingId == entry.value.bookingId,
                    isDeclining: _decliningBookingId == entry.value.bookingId,
                    rideTrackingService: _rideTrackingService,
                    onAccept: () => _acceptRide(entry.value),
                    onDecline: () => _declineRide(entry.value),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _decliningBookingId = null);
      }
    }
  }
}

class DriverRecentTripsSection extends StatelessWidget {
  final String driverId;

  const DriverRecentTripsSection({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final rideTrackingService = RideTrackingService();

    return StreamBuilder<List<DriverRecentTrip>>(
      stream: rideTrackingService.watchDriverRecentTrips(driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 126,
            child: PassengerSurfaceCard(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load recent trips',
            description: snapshot.error.toString(),
          );
        }

        final trips = snapshot.data ?? const <DriverRecentTrip>[];
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
                    bottom: entry.key == trips.length - 1 ? 0 : 12,
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

    return PassengerSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          _PassengerAvatar(profile: passenger),
          const SizedBox(width: 12),
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
                        style: PassengerUi.cardTitle.copyWith(fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (passenger.isVerified) ...[
                      const SizedBox(width: 6),
                      _MiniVerifiedBadge(),
                    ],
                    const SizedBox(width: 8),
                    PassengerStatusChip(
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
                const SizedBox(height: 5),
                Text(
                  passenger.roleLabel,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  _tripRouteLabel(ride),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      ride.fareLabel ?? 'Fare pending',
                      style: PassengerUi.valueText.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TimeAgoText(
                        dateTime: ride.updatedAt ?? ride.createdAt,
                        style: PassengerUi.bodyText.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _showRatingChoices(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: PassengerUi.mutedSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PassengerUi.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    rating == null
                        ? Icons.star_border_rounded
                        : Icons.star_rounded,
                    size: 18,
                    color: rating == null
                        ? PassengerUi.body
                        : PassengerUi.highlightAmber,
                  ),
                  if (rating != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: PassengerUi.valueText.copyWith(
                        fontSize: 12.5,
                        color: PassengerUi.highlightAmber,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingChoices(BuildContext context) async {
    final selectedRating = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PassengerRatingSheet(
        passengerName: trip.passenger.fullName,
        selectedRating: trip.ride.driverPassengerReviewRating,
      ),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _tripRouteLabel(Ride ride) {
    final pickup = ride.pickupLocation.displayLabel;
    final dropoff = ride.dropoffLocation.displayLabel;

    if (ride.distanceLabel != 'Calculating') {
      return '${ride.distanceLabel} - $pickup to $dropoff';
    }

    return '$pickup to $dropoff';
  }
}

class _PassengerAvatar extends StatelessWidget {
  final PassengerReviewProfile profile;

  const _PassengerAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.profileImageUrl;

    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
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

class _MiniVerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_rounded, size: 12, color: PassengerUi.accentBlue),
          const SizedBox(width: 3),
          Text(
            'Verified',
            style: PassengerUi.valueText.copyWith(
              fontSize: 10.5,
              color: PassengerUi.accentBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerRatingSheet extends StatelessWidget {
  final String passengerName;
  final int? selectedRating;

  const _PassengerRatingSheet({
    required this.passengerName,
    required this.selectedRating,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: PassengerUi.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PassengerUi.border),
          boxShadow: PassengerUi.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Review Passenger',
              style: PassengerUi.sectionTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              passengerName,
              style: PassengerUi.bodyText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final isSelected = rating == selectedRating;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).pop(rating),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PassengerUi.warningSoft
                          : PassengerUi.mutedSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? PassengerUi.highlightAmber
                            : PassengerUi.border,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.star_rounded,
                          color: PassengerUi.highlightAmber,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rating.toString(),
                          style: PassengerUi.valueText.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
