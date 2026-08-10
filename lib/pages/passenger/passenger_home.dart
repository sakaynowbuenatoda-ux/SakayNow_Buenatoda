import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../controllers/booking_map_controller.dart';
import '../../controllers/quick_destinations_controller.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../core/preferences/app_preferences_controller.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../models/ride_location.dart';
import '../../models/fare_settings.dart';
import '../../services/fare_settings_service.dart';
import '../../services/geofencing_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/maps/location_pin_picker_sheet.dart';
import '../../widgets/maps/map_text_styles.dart';
import '../../widgets/maps/map_type_toggle.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/driver_rating_leaderboard_panel.dart';
import '../../widgets/passenger_widgets/passenger_booking_hero_card.dart';
import '../../widgets/passenger_widgets/passenger_quick_destinations_section.dart';
import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/ride_status_strip.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../messages/ride_chat_navigation.dart';
import '../driver_ratings/driver_leaderboard_page.dart';
import '../rides/ride_monitoring_page.dart';
import 'passenger_data.dart';
import 'passenger_book_ride_page.dart';
import 'passenger_quick_destinations_page.dart';

class PassengerHomepage extends StatefulWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final bool isVerified;
  final String? profileImageUrl;
  final int notificationUnreadCount;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onBrandTap;
  final ValueChanged<String>? onProfileSelected;
  final VoidCallback onOpenHistory;

  const PassengerHomepage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.isVerified,
    this.profileImageUrl,
    this.notificationUnreadCount = 0,
    required this.onNotificationsTap,
    this.onBrandTap,
    this.onProfileSelected,
    required this.onOpenHistory,
  });

  @override
  State<PassengerHomepage> createState() => _PassengerHomepageState();
}

class _PassengerHomepageState extends State<PassengerHomepage> {
  late final QuickDestinationsController _quickDestinationsController;
  final LocationService _locationService = const LocationService();
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final GeofencingService _geofencingService = const GeofencingService();

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
    return StreamBuilder<Ride?>(
      stream: _rideTrackingService.watchPassengerActiveRide(widget.userId),
      builder: (context, snapshot) {
        final ride = snapshot.data;

        return PassengerHomeSplitLayout(
          map: _PassengerHomeMap(ride: ride),
          header: HomeMapHeader(
            firstName: widget.firstName,
            profileImageUrl: widget.profileImageUrl,
            greeting: widget.firstName.trim().isEmpty
                ? 'Welcome'
                : 'Welcome, ${widget.firstName.trim()}',
            showVerifiedBadge: widget.isVerified,
            notificationUnreadCount: widget.notificationUnreadCount,
            onNotificationsTap: widget.onNotificationsTap,
            onBrandTap: widget.onBrandTap,
            onProfileSelected: widget.onProfileSelected,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (ride != null)
                PassengerBookingHeroCard(
                  actionLabel: 'Continue Monitoring',
                  actionIcon: Icons.near_me_rounded,
                  onSecondaryAction: ride.hasDriver && !ride.status.isTerminal
                      ? () => _openRideChat(ride)
                      : null,
                  secondaryActionLabel: 'Message',
                  secondaryActionIcon: Icons.chat_bubble_rounded,
                  content: _RideMonitoringPreview(ride: ride, showMap: false),
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
                )
              else
                PassengerBookingHeroCard(
                  content: const _PassengerBookingCallout(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PassengerBookRidePage(
                        passengerId: widget.userId,
                        passengerType: widget.passengerType,
                        isVerified: widget.isVerified,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _AnimatedOneTapBookingCard(
                quickDestinationsController: _quickDestinationsController,
                onSeeAllTap: _openQuickDestinationsPage,
                onDestinationTap: _handleQuickDestinationTap,
              ),
              const SizedBox(height: 24),
              PassengerRecentTripsSection(
                passengerId: widget.userId,
                limit: 3,
                onViewAllTap: widget.onOpenHistory,
              ),
              const SizedBox(height: 24),
              DriverRatingLeaderboardPanel(
                limit: 5,
                actionLabel: 'See Top 20',
                onActionTap: _openDriverLeaderboard,
              ),
              const SizedBox(height: 24),
              _PassengerInformationKeySection(),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openRideChat(Ride ride) {
    return openRideChat(
      context: context,
      ride: ride,
      currentUserId: widget.userId,
      currentUserRole: 'passenger',
    );
  }

  void _openDriverLeaderboard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DriverLeaderboardPage()));
  }

  Future<void> _handleQuickDestinationTap(
    PassengerQuickDestination destination,
  ) async {
    if (!destination.hasCoordinates) {
      final savedDestination = await _setQuickDestinationLocation(destination);
      if (savedDestination != null) {
        await _requestOneTapRide(savedDestination);
      }
      return;
    }

    await _requestOneTapRide(destination);
  }

  Future<void> _requestOneTapRide(PassengerQuickDestination destination) async {
    if (!mounted) {
      return;
    }

    var dialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => const _OneTapBookingProcessingDialog(),
    );

    try {
      final bookingId = await _createOneTapBooking(destination);
      if (!mounted) {
        return;
      }

      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideMonitoringPage(
            bookingId: bookingId,
            userId: widget.userId,
            viewerRole: RideViewerRole.passenger,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      _showSnackBar(context, 'Unable to book destination: $error');
    }
  }

  Future<String> _createOneTapBooking(
    PassengerQuickDestination destination,
  ) async {
    final bookingController = BookingMapController(
      passengerId: widget.userId,
      passengerType: widget.passengerType,
      isPassengerVerified: widget.isVerified,
    );

    try {
      await bookingController.initialize();
      final pickup = bookingController.pickupLocation?.latLng;
      if (pickup == null) {
        throw StateError('Current location is required for one-tap booking.');
      }

      await bookingController.selectKnownLocation(
        target: BookingLocationTarget.dropoff,
        label: destination.label,
        address: destination.bookingAddress,
        name: destination.pinDisplayLabel,
        placeId: destination.pinPlaceId,
        useLabelAsName: false,
        latitude: destination.latitude,
        longitude: destination.longitude,
      );

      final preferredDriver = await _bestDriverForPickup(pickup);
      final bookingId = await bookingController.createBooking(
        preferredDriverId: preferredDriver?.driverId,
      );

      if (bookingId == null) {
        throw StateError(
          bookingController.errorMessage ?? 'Unable to create booking.',
        );
      }

      return bookingId;
    } finally {
      bookingController.dispose();
    }
  }

  Future<AvailableDriver?> _bestDriverForPickup(LatLng pickup) async {
    final drivers = await _rideTrackingService
        .watchAvailableDrivers()
        .first
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () => <AvailableDriver>[],
        );

    final eligibleDrivers = drivers
        .where(
          (driver) => _geofencingService.isDriverInsideBookingGeofence(
            driverLocation: driver.location.latLng,
            pickupLocation: pickup,
          ),
        )
        .toList();

    if (eligibleDrivers.isEmpty) {
      return null;
    }

    eligibleDrivers.sort((a, b) {
      final aScore = _driverMatchScore(a, pickup);
      final bScore = _driverMatchScore(b, pickup);
      return bScore.compareTo(aScore);
    });

    return eligibleDrivers.first;
  }

  double _driverMatchScore(AvailableDriver driver, LatLng pickup) {
    final distance = _geofencingService.distanceBetweenMeters(
      driver.location.latLng,
      pickup,
    );
    final ratingScore = (driver.rating.clamp(0, 5) / 5) * 0.65;
    final distanceScore =
        (1 - (distance / MapConfig.bookingGeofenceRadiusMeters).clamp(0, 1)) *
        0.35;

    return ratingScore + distanceScore;
  }

  Future<PassengerQuickDestination?> _setQuickDestinationLocation(
    PassengerQuickDestination destination,
  ) async {
    final pickerTarget = await _quickDestinationPickerTarget(destination);
    if (!mounted) {
      return null;
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
        heightFactor: 0.9,
      ),
    );

    if (selected == null) {
      return null;
    }

    final location = await _locationFromPin(selected);
    final savedDestination = destination.copyWith(
      address: _savedDestinationAddress(location),
      pinName: _pinNameFromLocation(location),
      pinPlaceId: location.placeId,
      clearPinDetails: !_hasPinDetails(location),
      latitude: location.latitude,
      longitude: location.longitude,
    );
    try {
      await _quickDestinationsController.upsert(savedDestination);
      return savedDestination;
    } on Exception catch (error) {
      if (mounted) {
        _showSnackBar(context, 'Unable to save destination: $error');
      }
      return null;
    }
  }

  Future<RideLocation> _locationFromPin(LocationPinPickResult selected) async {
    final googlePlace = selected.googlePlace;
    if (googlePlace != null) {
      return googlePlace;
    }

    final location = selected.location;
    final coordinateLabel =
        '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    return RideLocation(
      address: coordinateLabel,
      latitude: location.latitude,
      longitude: location.longitude,
    );
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

  String _savedDestinationAddress(RideLocation location) {
    return _hasPinDetails(location)
        ? location.address
        : location.coordinateLabel ?? location.address;
  }

  String? _pinNameFromLocation(RideLocation location) {
    final name = location.name?.trim();
    if (name == null || name.isEmpty || name == 'Pinned location') {
      return null;
    }

    return name;
  }

  String? _pinDisplayText(RideLocation location) {
    return location.googlePinDisplayLabel ?? _pinNameFromLocation(location);
  }

  bool _hasPinDetails(RideLocation location) {
    return _pinDisplayText(location) != null;
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

class _AnimatedOneTapBookingCard extends StatefulWidget {
  final QuickDestinationsController quickDestinationsController;
  final VoidCallback onSeeAllTap;
  final ValueChanged<PassengerQuickDestination> onDestinationTap;

  const _AnimatedOneTapBookingCard({
    required this.quickDestinationsController,
    required this.onSeeAllTap,
    required this.onDestinationTap,
  });

  @override
  State<_AnimatedOneTapBookingCard> createState() =>
      _AnimatedOneTapBookingCardState();
}

class _AnimatedOneTapBookingCardState extends State<_AnimatedOneTapBookingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    // Slight delay so it appears after the hero card
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PassengerUi.isDarkMode;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                isDark ? const Color(0xFF111827) : Colors.white,
                isDark ? const Color(0xFF0F1420) : const Color(0xFFF9FAFB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF1E2536) : const Color(0xFFE2E6EE),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _OneTapBookingHeader(onActionTap: widget.onSeeAllTap),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: widget.quickDestinationsController,
                    builder: (context, _) {
                      return PassengerQuickDestinationsSection(
                        destinations:
                            widget.quickDestinationsController.destinations,
                        onSeeAllTap: widget.onSeeAllTap,
                        onDestinationTap: widget.onDestinationTap,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OneTapBookingHeader extends StatefulWidget {
  final VoidCallback onActionTap;

  const _OneTapBookingHeader({required this.onActionTap});

  @override
  State<_OneTapBookingHeader> createState() => _OneTapBookingHeaderState();
}

class _OneTapBookingHeaderState extends State<_OneTapBookingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;
  late final Animation<double> _iconGlowAnimation;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _iconGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final isDark = PassengerUi.isDarkMode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        AnimatedBuilder(
          animation: _iconGlowAnimation,
          builder: (context, child) {
            final glow = _iconGlowAnimation.value;

            return Container(
              width: compact ? 40 : 44,
              height: compact ? 40 : 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color.lerp(
                      isDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFDCFCE7),
                      isDark
                          ? const Color(0xFF065F46)
                          : const Color(0xFFC6F6D5),
                      glow,
                    )!,
                    Color.lerp(
                      isDark
                          ? const Color(0xFF053B2C)
                          : const Color(0xFFE7F8EF),
                      isDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFDCFCE7),
                      glow,
                    )!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: PassengerUi.successText.withValues(
                      alpha: 0.12 + (glow * 0.08),
                    ),
                    blurRadius: 8 + (glow * 4),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Icon(
            Icons.flash_on_rounded,
            color: PassengerUi.successText,
            size: compact ? 22 : 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: PassengerUi.successText,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'One-tap booking',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.cardTitle.copyWith(
                        fontSize: compact ? 15.5 : 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pick a saved destination and ride faster.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PassengerUi.bodyText.copyWith(
                  fontSize: compact ? 11.5 : 12.5,
                  color: PassengerUi.body.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onActionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'See all',
                    style: TextStyle(
                      color: PassengerUi.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: PassengerUi.primary,
                    size: 11,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PassengerInformationKeySection extends StatelessWidget {
  final FareSettingsService fareSettingsService;

  _PassengerInformationKeySection({FareSettingsService? fareSettingsService})
    : fareSettingsService = fareSettingsService ?? FareSettingsService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FareSettings>(
      stream: fareSettingsService.watchSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data ?? FareSettings.defaults;
        final items = _itemsFor(settings);

        return PassengerSurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Information Key',
                style: PassengerUi.sectionTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Helpful fare, payment, and discount details before you ride.',
                style: PassengerUi.bodyText,
              ),
              SizedBox(height: 14),
              ...items.asMap().entries.map(
                (MapEntry<int, _InformationKeyItem> entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == items.length - 1 ? 0 : 12,
                  ),
                  child: _InformationKeyTile(item: entry.value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_InformationKeyItem> _itemsFor(FareSettings settings) {
    return <_InformationKeyItem>[
      _InformationKeyItem(
        icon: Icons.receipt_long_rounded,
        title: 'Local LGU fare guide',
        description: settings.passengerFareGuideDescription,
      ),
      const _InformationKeyItem(
        icon: Icons.payments_rounded,
        title: 'Approved payment methods',
        description:
            'Cash, GCash, Maya, and Xendit checkout are supported when available.',
      ),
      _InformationKeyItem(
        icon: Icons.person_outline_rounded,
        title: 'Regular passenger discount',
        description: settings.passengerRegularDiscountDescription,
      ),
      _InformationKeyItem(
        icon: Icons.school_rounded,
        title: 'Student discount',
        description: settings.passengerStudentDiscountDescription,
      ),
      _InformationKeyItem(
        icon: Icons.elderly_rounded,
        title: 'Senior citizen discount',
        description: settings.passengerSeniorCitizenDiscountDescription,
      ),
      const _InformationKeyItem(
        icon: Icons.local_offer_rounded,
        title: 'Current discounts',
        description:
            'Active promos and special discounts are applied before checkout.',
      ),
    ];
  }
}

class _InformationKeyItem {
  final IconData icon;
  final String title;
  final String description;

  const _InformationKeyItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _InformationKeyTile extends StatelessWidget {
  final _InformationKeyItem item;

  const _InformationKeyTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: PassengerUi.blueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: PassengerUi.accentBlue, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                style: PassengerUi.cardTitle.copyWith(fontSize: 14),
              ),
              SizedBox(height: 2),
              Text(item.description, style: PassengerUi.bodyText),
            ],
          ),
        ),
      ],
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

class _OneTapBookingProcessingDialog extends StatelessWidget {
  const _OneTapBookingProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PassengerUi.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PassengerUi.border),
            boxShadow: PassengerUi.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Finding a driver',
                  style: PassengerUi.sectionTitle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Preparing your ride request...',
                  style: PassengerUi.bodyText,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PassengerBookingCallout extends StatelessWidget {
  const _PassengerBookingCallout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PassengerUi.blueSoft,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(Icons.my_location_rounded, color: PassengerUi.accentBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ready when you are',
                style: PassengerUi.cardTitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a pickup and destination to request your ride.',
                style: PassengerUi.bodyText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassengerHomeMap extends StatefulWidget {
  final Ride? ride;

  const _PassengerHomeMap({required this.ride});

  @override
  State<_PassengerHomeMap> createState() => _PassengerHomeMapState();
}

class _PassengerHomeMapState extends State<_PassengerHomeMap> {
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
        final ride = widget.ride;
        final location = ride == null
            ? snapshot.data ?? MapConfig.buenavistaCenter
            : _RideMonitoringPreview._initialTarget(ride);
        final hasLocation = snapshot.hasData;

        return LayoutBuilder(
          builder: (context, constraints) {
            final controlsTop =
                MediaQuery.paddingOf(context).top +
                (PassengerUi.isCompactWidth(context) ? 88 : 96);

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedBuilder(
                  animation: AppPreferencesController.instance,
                  builder: (context, _) {
                    return SakayGoogleMap(
                      initialCameraTarget: location,
                      bounds: ride == null
                          ? null
                          : _RideMonitoringPreview._boundsFor(ride),
                      markers: ride != null
                          ? _RideMonitoringPreview._markersFor(ride)
                          : hasLocation
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
                      polylines: ride == null
                          ? const <Polyline>{}
                          : _RideMonitoringPreview._polylinesFor(ride),
                      mapType: AppPreferencesController.instance.googleMapType,
                      myLocationEnabled: ride == null && hasLocation,
                      autoMoveCamera: true,
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  top: controlsTop,
                  child: const MapTypeToggle(),
                ),
                Positioned(
                  left: 8,
                  right: 112,
                  top: controlsTop,
                  child: _MapOverlayPill(
                    icon: ride != null
                        ? Icons.route_rounded
                        : hasLocation
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    text: ride != null
                        ? ride.status.label
                        : hasLocation
                        ? 'Live map'
                        : snapshot.hasError
                        ? 'Location unavailable'
                        : 'Finding location',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RideMonitoringPreview extends StatelessWidget {
  final Ride ride;
  final bool showMap;

  const _RideMonitoringPreview({required this.ride, this.showMap = true});

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
        if (showMap) ...<Widget>[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: PassengerUi.cardRadius,
            child: SizedBox(
              height: 180,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: AppPreferencesController.instance,
                      builder: (context, _) {
                        return SakayGoogleMap(
                          initialCameraTarget: _initialTarget(ride),
                          bounds: _boundsFor(ride),
                          markers: _markersFor(ride),
                          polylines: _polylinesFor(ride),
                          mapType:
                              AppPreferencesController.instance.googleMapType,
                          autoMoveCamera: true,
                        );
                      },
                    ),
                  ),
                  const Positioned(top: 10, right: 10, child: MapTypeToggle()),
                ],
              ),
            ),
          ),
        ],
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
