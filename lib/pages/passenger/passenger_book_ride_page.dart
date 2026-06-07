import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../controllers/booking_map_controller.dart';
import '../../controllers/quick_destinations_controller.dart';
import '../../models/driver_rating.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../models/place_prediction.dart';
import '../../models/passenger_payment_method.dart';
import '../../models/ride_location.dart';
import '../../models/ride_status.dart';
import '../../services/geofencing_service.dart';
import '../../services/payment_method_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../services/xendit_checkout_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/maps/location_pin_picker_sheet.dart';
import '../../widgets/maps/place_search_field.dart';
import '../../widgets/maps/route_summary_card.dart';
import '../../widgets/maps/map_text_styles.dart';
import '../../widgets/maps/map_marker_icons.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/passenger_widgets/ride_status_strip.dart';
import '../rides/ride_monitoring_page.dart';
import 'passenger_data.dart';

class PassengerBookRidePage extends StatefulWidget {
  final String passengerId;
  final String passengerType;
  final bool isVerified;
  final PassengerQuickDestination? initialDropoffDestination;

  const PassengerBookRidePage({
    super.key,
    required this.passengerId,
    this.passengerType = 'regular',
    this.isVerified = false,
    this.initialDropoffDestination,
  });

  @override
  State<PassengerBookRidePage> createState() => _PassengerBookRidePageState();
}

class _PassengerBookRidePageState extends State<PassengerBookRidePage> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final PaymentMethodService _paymentMethodService = PaymentMethodService();
  late final BookingMapController _controller;
  late final QuickDestinationsController _quickDestinationsController;
  BookingLocationTarget _activeMapTarget = BookingLocationTarget.dropoff;
  String? _selectedPaymentMethodId;

  @override
  void initState() {
    super.initState();
    _controller = BookingMapController(
      passengerId: widget.passengerId,
      passengerType: widget.passengerType,
      isPassengerVerified: widget.isVerified,
    );
    _quickDestinationsController = QuickDestinationsController(
      userId: widget.passengerId,
    )..load();
    _pickupController.addListener(_rebuildForTypedLocations);
    _destinationController.addListener(_rebuildForTypedLocations);
    _initialize();
  }

  @override
  void dispose() {
    _pickupController.removeListener(_rebuildForTypedLocations);
    _destinationController.removeListener(_rebuildForTypedLocations);
    _pickupController.dispose();
    _destinationController.dispose();
    _controller.dispose();
    _quickDestinationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.background,
        elevation: 0,
        surfaceTintColor: PassengerUi.background,
        title: Text('Book a Ride', style: MapTextStyles.title),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: PassengerUi.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PassengerSurfaceCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: <Widget>[
                        _MapTargetSelector(
                          activeTarget: _activeMapTarget,
                          onChanged: (target) =>
                              setState(() => _activeMapTarget = target),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: PassengerUi.cardRadius,
                          child: SizedBox(
                            height: compact ? 220 : 260,
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: SakayGoogleMap(
                                    initialCameraTarget:
                                        _controller.initialCameraTarget,
                                    bounds: _controller.route?.bounds,
                                    markers: _bookingMapMarkers(),
                                    polylines: _controller.polylines,
                                    circles: _controller.circles,
                                    myLocationEnabled:
                                        _controller.currentLatLng != null,
                                    preferInitialCameraTarget: true,
                                    onTap: _selectLocationFromMapTap,
                                  ),
                                ),
                                if (_controller.isInitializing)
                                  const Positioned.fill(
                                    child: ColoredBox(
                                      color: Color(0x66FFFFFF),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_controller.locationMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _InlineNotice(
                      icon: Icons.location_off_rounded,
                      message: _controller.locationMessage!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  PlaceSearchField(
                    controller: _pickupController,
                    label: 'Pickup location',
                    hintText: 'Search places in Buenavista, Inabanga, Getafe',
                    icon: Icons.my_location_rounded,
                    iconColor: PassengerUi.secondary,
                    isLoading: _controller.isPickupSearching,
                    predictions: _controller.pickupPredictions,
                    onSearchChanged: _controller.searchPickup,
                    onPredictionSelected: _selectPickup,
                    onUseCurrentLocation: _useCurrentLocationAsPickup,
                    onPickFromMap: () =>
                        _pickLocationOnMap(BookingLocationTarget.pickup),
                  ),
                  const SizedBox(height: 12),
                  PlaceSearchField(
                    controller: _destinationController,
                    label: 'Drop-off location',
                    hintText: 'Search places in Buenavista, Inabanga, Getafe',
                    icon: Icons.location_on_rounded,
                    iconColor: PassengerUi.primary,
                    isLoading: _controller.isDropoffSearching,
                    predictions: _controller.dropoffPredictions,
                    onSearchChanged: _controller.searchDropoff,
                    onPredictionSelected: _selectDropoff,
                    onPickFromMap: () =>
                        _pickLocationOnMap(BookingLocationTarget.dropoff),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _quickDestinationsController,
                    builder: (context, _) {
                      return _SavedDestinationRow(
                        destinations: _quickDestinationsController.destinations,
                        isLoading: _quickDestinationsController.isLoading,
                        onTap: _applySavedDestination,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  RouteSummaryCard(
                    route: _controller.route,
                    estimate: _controller.estimate,
                    fareEstimate: _controller.fareEstimate,
                    fareNotice: _controller.fareNotice,
                    isLoading: _controller.isRouteLoading,
                    errorMessage: _controller.errorMessage,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<PassengerPaymentMethod>>(
                    stream: _paymentMethodService.watchPaymentMethods(
                      widget.passengerId,
                    ),
                    builder: (context, snapshot) {
                      final methods =
                          snapshot.data ??
                          <PassengerPaymentMethod>[
                            PassengerPaymentMethod.cash(
                              userId: widget.passengerId,
                            ),
                          ];
                      final selected = _selectedPaymentMethod(methods);

                      return _BookingPaymentMethodCard(
                        selectedMethod: selected,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                        onChange: () => _showPaymentMethodPicker(methods),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  PassengerSurfaceCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.radar_rounded,
                          color: PassengerUi.accentBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Booking now checks drivers within a wider barangay-scale geofence around your pickup.',
                            style: MapTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _controller.canCreateBooking
                          ? _openDriverSelectionPanel
                          : _hasTypedLocations
                          ? _openDriverSelectionPanel
                          : null,
                      icon: _controller.isBookingLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.two_wheeler_rounded),
                      label: Text(
                        _controller.isBookingLoading
                            ? 'Requesting Ride...'
                            : 'Request Ride',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _hasTypedLocations =>
      _pickupController.text.trim().isNotEmpty &&
      _destinationController.text.trim().isNotEmpty;

  void _rebuildForTypedLocations() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initialize() async {
    MapMarkerIcons.load().then((icons) {
      if (mounted) {
        _controller.setMarkerIcons(icons);
      }
    });
    await _controller.initialize();
    final activeRide = await _controller.findActiveRide();
    if (mounted && activeRide != null) {
      _openRide(activeRide.bookingId);
      return;
    }

    final pickup = _controller.pickupLocation;
    if (!mounted || pickup == null) {
      return;
    }

    _pickupController.text = _pickupDisplayText(pickup);
    final initialDropoff = widget.initialDropoffDestination;
    if (initialDropoff?.hasCoordinates == true) {
      await _applyDestinationToTarget(
        initialDropoff!,
        BookingLocationTarget.dropoff,
      );
    }
  }

  Future<void> _useCurrentLocationAsPickup() async {
    final location = await _controller.useCurrentLocationAsPickup();
    if (location != null) {
      _pickupController.text = _pickupDisplayText(location);
      setState(() => _activeMapTarget = BookingLocationTarget.dropoff);
    }
  }

  Future<void> _selectPickup(PlacePrediction prediction) async {
    try {
      final location = await _controller.selectPickup(prediction);
      if (!mounted) {
        return;
      }

      _pickupController.text = _pickupDisplayText(location);
      setState(() => _activeMapTarget = BookingLocationTarget.dropoff);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString());
    }
  }

  Future<void> _selectDropoff(PlacePrediction prediction) async {
    try {
      final location = await _controller.selectDropoff(prediction);
      if (!mounted) {
        return;
      }

      _destinationController.text = _locationDisplayText(location);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString());
    }
  }

  Future<void> _pickLocationOnMap(BookingLocationTarget target) async {
    final selected = await showModalBottomSheet<LocationPinPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPinPickerSheet(
        title: target == BookingLocationTarget.pickup
            ? 'Pin Pickup'
            : 'Pin Drop-off',
        actionLabel: target == BookingLocationTarget.pickup
            ? 'Set Pickup Location'
            : 'Set Drop-off Location',
        accentColor: target == BookingLocationTarget.pickup
            ? PassengerUi.secondary
            : PassengerUi.primary,
        initialTarget:
            (target == BookingLocationTarget.pickup
                ? _controller.pickupLocation?.latLng
                : _controller.dropoffLocation?.latLng) ??
            _controller.currentLatLng ??
            MapConfig.buenavistaCenter,
        myLocationEnabled: _controller.currentLatLng != null,
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    late final RideLocation location;
    try {
      final selectedPlace = selected.googlePlace;
      location = selectedPlace != null
          ? await _controller.selectResolvedLocation(
              target: target,
              location: selectedPlace,
            )
          : target == BookingLocationTarget.pickup
          ? await _controller.selectPickupFromPin(selected.location)
          : await _controller.selectDropoffFromPin(selected.location);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString());
      return;
    }

    if (!mounted) {
      return;
    }
    _writeLocationToField(target, _locationDisplayText(location));
    if (target == BookingLocationTarget.pickup) {
      setState(() => _activeMapTarget = BookingLocationTarget.dropoff);
    }
  }

  Future<void> _selectLocationFromMapTap(LatLng location) async {
    final target = _activeMapTarget;
    late final RideLocation rideLocation;
    try {
      rideLocation = target == BookingLocationTarget.pickup
          ? await _controller.selectPickupFromPin(location)
          : await _controller.selectDropoffFromPin(location);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString());
      return;
    }

    if (!mounted) {
      return;
    }

    _writeLocationToField(target, _locationDisplayText(rideLocation));
    if (target == BookingLocationTarget.pickup) {
      setState(() => _activeMapTarget = BookingLocationTarget.dropoff);
    }
  }

  Future<void> _applySavedDestination(
    PassengerQuickDestination destination,
  ) async {
    await _applyDestinationToTarget(destination, _activeMapTarget);
  }

  Future<void> _applyDestinationToTarget(
    PassengerQuickDestination destination,
    BookingLocationTarget target,
  ) async {
    if (!destination.hasCoordinates) {
      _showSnackBar('Set ${destination.label} first.');
      return;
    }

    try {
      final location = await _controller.selectKnownLocation(
        target: target,
        label: destination.label,
        address: destination.address ?? destination.label,
        latitude: destination.latitude,
        longitude: destination.longitude,
      );

      if (!mounted) {
        return;
      }

      _writeLocationToField(target, _locationDisplayText(location));
      if (target == BookingLocationTarget.pickup) {
        setState(() => _activeMapTarget = BookingLocationTarget.dropoff);
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString());
    }
  }

  Future<void> _openDriverSelectionPanel() async {
    final ready = await _controller.resolveTypedLocations(
      pickupText: _pickupController.text,
      dropoffText: _destinationController.text,
    );
    if (!mounted) {
      return;
    }

    _syncFieldsFromController();

    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ??
                'Select a valid pickup and drop-off location first.',
          ),
        ),
      );
      return;
    }

    final paymentMethods = await _paymentMethodService.loadPaymentMethods(
      widget.passengerId,
    );
    if (!mounted) {
      return;
    }

    final paymentMethod = _selectedPaymentMethod(paymentMethods);

    final bookingId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverSelectionPanel(
        controller: _controller,
        paymentMethod: paymentMethod,
      ),
    );

    if (!mounted || bookingId == null) {
      return;
    }

    _openRide(bookingId);
  }

  void _writeLocationToField(BookingLocationTarget target, String address) {
    if (target == BookingLocationTarget.pickup) {
      _pickupController.text = address;
    } else {
      _destinationController.text = address;
    }
  }

  String _locationDisplayText(RideLocation location) {
    return location.displayLabel;
  }

  String _pickupDisplayText(RideLocation location) {
    if (_controller.isPickupCurrentLocation) {
      return 'Current location';
    }

    return _locationDisplayText(location);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  PassengerPaymentMethod _selectedPaymentMethod(
    List<PassengerPaymentMethod> methods,
  ) {
    if (methods.isEmpty) {
      return PassengerPaymentMethod.cash(userId: widget.passengerId);
    }

    final selectedId = _selectedPaymentMethodId;
    if (selectedId != null) {
      for (final method in methods) {
        if (method.id == selectedId) {
          return method;
        }
      }
    }

    for (final method in methods) {
      if (method.isDefault) {
        return method;
      }
    }

    return methods.first;
  }

  Future<void> _showPaymentMethodPicker(
    List<PassengerPaymentMethod> methods,
  ) async {
    final selected = await showModalBottomSheet<PassengerPaymentMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodPickerSheet(
        methods: methods,
        selectedMethodId: _selectedPaymentMethod(methods).id,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() => _selectedPaymentMethodId = selected.id);
  }

  void _syncFieldsFromController() {
    final pickup = _controller.pickupLocation;
    final dropoff = _controller.dropoffLocation;
    if (pickup != null) {
      _pickupController.text = _pickupDisplayText(pickup);
    }
    if (dropoff != null) {
      _destinationController.text = _locationDisplayText(dropoff);
    }
  }

  Set<Marker> _bookingMapMarkers() {
    return _controller.markers;
  }

  void _openRide(String bookingId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RideMonitoringPage(
          bookingId: bookingId,
          userId: widget.passengerId,
          viewerRole: RideViewerRole.passenger,
        ),
      ),
    );
  }
}

class _BookingPaymentMethodCard extends StatelessWidget {
  final PassengerPaymentMethod selectedMethod;
  final bool isLoading;
  final VoidCallback onChange;

  const _BookingPaymentMethodCard({
    required this.selectedMethod,
    required this.isLoading,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selectedMethod.type.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              selectedMethod.type.icon,
              color: selectedMethod.type.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Payment',
                  style: MapTextStyles.body.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoading ? 'Loading...' : selectedMethod.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.value,
                ),
                if (!isLoading) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    selectedMethod.usesOnlineCheckout
                        ? '${selectedMethod.accountLabel} - driver must support online'
                        : selectedMethod.accountLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MapTextStyles.body.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : onChange,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodPickerSheet extends StatelessWidget {
  final List<PassengerPaymentMethod> methods;
  final String selectedMethodId;

  const _PaymentMethodPickerSheet({
    required this.methods,
    required this.selectedMethodId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
            Text('Choose Payment', style: MapTextStyles.title),
            const SizedBox(height: 12),
            for (final method in methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: method.type.accentColor.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(method.type.icon, color: method.type.accentColor),
                ),
                title: Text(method.displayLabel, style: MapTextStyles.value),
                subtitle: Text(
                  method.accountLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.body.copyWith(fontSize: 12),
                ),
                trailing: method.id == selectedMethodId
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: PassengerUi.successText,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(method),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapTargetSelector extends StatelessWidget {
  final BookingLocationTarget activeTarget;
  final ValueChanged<BookingLocationTarget> onChanged;

  const _MapTargetSelector({
    required this.activeTarget,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PassengerUi.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PassengerUi.border),
          boxShadow: PassengerUi.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TargetButton(
              label: 'Pickup',
              icon: Icons.my_location_rounded,
              color: PassengerUi.secondary,
              isSelected: activeTarget == BookingLocationTarget.pickup,
              onTap: () => onChanged(BookingLocationTarget.pickup),
            ),
            _TargetButton(
              label: 'Drop-off',
              icon: Icons.location_on_rounded,
              color: PassengerUi.primary,
              isSelected: activeTarget == BookingLocationTarget.dropoff,
              onTap: () => onChanged(BookingLocationTarget.dropoff),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TargetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : PassengerUi.body,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: MapTextStyles.body.copyWith(
                  color: isSelected ? color : PassengerUi.body,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverSelectionPanel extends StatefulWidget {
  final BookingMapController controller;
  final PassengerPaymentMethod paymentMethod;

  const _DriverSelectionPanel({
    required this.controller,
    required this.paymentMethod,
  });

  @override
  State<_DriverSelectionPanel> createState() => _DriverSelectionPanelState();
}

class _DriverSelectionPanelState extends State<_DriverSelectionPanel> {
  final GeofencingService _geofencingService = const GeofencingService();
  final XenditCheckoutService _xenditCheckoutService = XenditCheckoutService();
  bool _isExpanded = false;
  String? _bookingDriverId;

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.90;
    final pickup = widget.controller.pickupLocation?.latLng;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: PassengerUi.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: StreamBuilder<List<AvailableDriver>>(
        stream: widget.controller.watchAvailableDrivers(),
        builder: (context, snapshot) {
          final drivers = snapshot.data ?? <AvailableDriver>[];
          final sortedDrivers = _sortDrivers(drivers, pickup);
          final nearbyDrivers = _nearbyDrivers(sortedDrivers, pickup);
          final otherActiveDrivers = _otherActiveDrivers(
            sortedDrivers,
            nearbyDrivers,
          );
          final mapHeight = _isExpanded ? sheetHeight * 0.52 : 220.0;
          final selectedDriver = _selectedBookingDriver(sortedDrivers);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: PassengerUi.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Available Drivers', style: MapTextStyles.title),
                          const SizedBox(height: 4),
                          Text(
                            '${nearbyDrivers.length} nearby - ${sortedDrivers.length} active verified',
                            style: MapTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _isExpanded ? 'Collapse map' : 'Expand map',
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      icon: Icon(
                        _isExpanded
                            ? Icons.unfold_less_rounded
                            : Icons.unfold_more_rounded,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: mapHeight,
                  child: ClipRRect(
                    borderRadius: PassengerUi.cardRadius,
                    child: SakayGoogleMap(
                      initialCameraTarget:
                          pickup ?? widget.controller.initialCameraTarget,
                      bounds: widget.controller.route?.bounds,
                      markers: _driverMarkers(sortedDrivers),
                      polylines: widget.controller.polylines,
                      circles: _driverCircles(),
                      myLocationEnabled:
                          widget.controller.currentLatLng != null,
                    ),
                  ),
                ),
              ),
              if (_bookingDriverId != null) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: RideStatusStrip(
                    status: RideStatus.searching,
                    isPendingDriver: selectedDriver != null,
                    driverName: selectedDriver?.fullName,
                    driverImageUrl: selectedDriver?.profileImageUrl,
                    driverRatingLabel: selectedDriver?.rating.toStringAsFixed(
                      1,
                    ),
                    isDriverVerified: selectedDriver?.isVerified ?? false,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    14 + PassengerUi.pageBottomInset(context),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : _DriverPanelContent(
                          nearbyDrivers: nearbyDrivers,
                          otherActiveDrivers: otherActiveDrivers,
                          hasPickup: pickup != null,
                          bookingDriverId: _bookingDriverId,
                          isRequestingAny: _bookingDriverId == 'any',
                          isBookingLoading: widget.controller.isBookingLoading,
                          fareLabel:
                              widget.controller.fareEstimate?.amountLabel ??
                              'Fare pending',
                          fareNote: widget.controller.fareNotice,
                          paymentMethod: widget.paymentMethod,
                          distanceLabelBuilder: (driver) =>
                              _distanceLabel(driver, pickup),
                          onBookDriver: _bookDriver,
                          onRequestAnyway: () => _bookDriver(null),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  AvailableDriver? _selectedBookingDriver(List<AvailableDriver> drivers) {
    final bookingDriverId = _bookingDriverId;
    if (bookingDriverId == null || bookingDriverId == 'any') {
      return null;
    }

    for (final driver in drivers) {
      if (driver.driverId == bookingDriverId) {
        return driver;
      }
    }

    return null;
  }

  List<AvailableDriver> _sortDrivers(
    List<AvailableDriver> drivers,
    LatLng? pickup,
  ) {
    final sorted = [...drivers];
    if (pickup == null) {
      return sorted;
    }

    sorted.sort((a, b) {
      final aDistance = _geofencingService.distanceBetweenMeters(
        a.location.latLng,
        pickup,
      );
      final bDistance = _geofencingService.distanceBetweenMeters(
        b.location.latLng,
        pickup,
      );
      final distanceDifference = (aDistance - bDistance).abs();
      if (distanceDifference <= DriverRating.closeDistanceTieMeters) {
        final rankComparison = _compareDriverRank(a, b);
        if (rankComparison != 0) {
          return rankComparison;
        }
      }

      return aDistance.compareTo(bDistance);
    });
    return sorted;
  }

  int _compareDriverRank(AvailableDriver a, AvailableDriver b) {
    final aRank = a.ratingRank;
    final bRank = b.ratingRank;

    if (aRank != null && bRank != null && aRank != bRank) {
      return aRank.compareTo(bRank);
    }

    if (aRank != null && bRank == null) {
      return -1;
    }

    if (aRank == null && bRank != null) {
      return 1;
    }

    final weightedComparison = b.weightedRating.compareTo(a.weightedRating);
    if (weightedComparison != 0) {
      return weightedComparison;
    }

    return b.reviewCount.compareTo(a.reviewCount);
  }

  List<AvailableDriver> _nearbyDrivers(
    List<AvailableDriver> drivers,
    LatLng? pickup,
  ) {
    if (pickup == null) {
      return drivers;
    }

    return drivers
        .where(
          (driver) => _geofencingService.isDriverInsideBookingGeofence(
            driverLocation: driver.location.latLng,
            pickupLocation: pickup,
          ),
        )
        .toList();
  }

  List<AvailableDriver> _otherActiveDrivers(
    List<AvailableDriver> drivers,
    List<AvailableDriver> nearbyDrivers,
  ) {
    final nearbyIds = nearbyDrivers.map((driver) => driver.driverId).toSet();
    return drivers
        .where((driver) => !nearbyIds.contains(driver.driverId))
        .toList();
  }

  Set<Marker> _driverMarkers(List<AvailableDriver> drivers) {
    final markers = <Marker>{...widget.controller.markers};
    for (final driver in drivers) {
      markers.add(
        Marker(
          markerId: MarkerId('driver_${driver.driverId}'),
          position: driver.location.latLng,
          infoWindow: InfoWindow(title: driver.fullName),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _driverCircles() {
    final pickup = widget.controller.pickupLocation?.latLng;
    if (pickup == null) {
      return widget.controller.circles;
    }

    return <Circle>{
      ...widget.controller.circles,
      Circle(
        circleId: const CircleId('available_driver_radius'),
        center: pickup,
        radius: MapConfig.bookingGeofenceRadiusMeters,
        fillColor: PassengerUi.accentBlue.withValues(alpha: 0.07),
        strokeColor: PassengerUi.accentBlue.withValues(alpha: 0.55),
        strokeWidth: 1,
      ),
    };
  }

  String _distanceLabel(AvailableDriver driver, LatLng? pickup) {
    if (pickup == null) {
      return 'Nearby';
    }

    final distance = _geofencingService.distanceBetweenMeters(
      driver.location.latLng,
      pickup,
    );
    final seconds = _geofencingService.approximateDurationSeconds(distance);
    final minutes = (seconds / 60).ceil().clamp(1, 999);
    final distanceText = distance < 1000
        ? '${distance.round()} m'
        : '${(distance / 1000).toStringAsFixed(1)} km';

    return '$minutes min away - $distanceText';
  }

  Future<void> _bookDriver(AvailableDriver? driver) async {
    final driverId = driver?.driverId;
    final paymentMethod = _effectivePaymentMethod(driver);

    setState(() => _bookingDriverId = driverId ?? 'any');
    final bookingId = await widget.controller.createBooking(
      preferredDriverId: driverId,
      paymentMethod: paymentMethod,
    );

    if (!mounted) {
      return;
    }

    if (bookingId != null) {
      if (paymentMethod.usesOnlineCheckout) {
        try {
          final session = await _xenditCheckoutService.createCheckoutSession(
            bookingId: bookingId,
            paymentMethod: paymentMethod,
          );
          await _xenditCheckoutService.openCheckoutUrl(session.checkoutUrl);
        } on Exception catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Xendit checkout failed: $error')),
            );
          }
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(bookingId);
      return;
    }

    setState(() => _bookingDriverId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.errorMessage ?? 'Unable to request ride.',
        ),
      ),
    );
  }

  PassengerPaymentMethod _effectivePaymentMethod(AvailableDriver? driver) {
    final selected = widget.paymentMethod;
    if (!selected.usesOnlineCheckout) {
      return selected;
    }

    if (driver?.supportsOnlinePayments == true) {
      return selected;
    }

    return PassengerPaymentMethod.cash(userId: widget.controller.passengerId);
  }
}

class _DriverPanelContent extends StatelessWidget {
  final List<AvailableDriver> nearbyDrivers;
  final List<AvailableDriver> otherActiveDrivers;
  final bool hasPickup;
  final String? bookingDriverId;
  final bool isRequestingAny;
  final bool isBookingLoading;
  final String fareLabel;
  final String? fareNote;
  final PassengerPaymentMethod paymentMethod;
  final String Function(AvailableDriver driver) distanceLabelBuilder;
  final ValueChanged<AvailableDriver> onBookDriver;
  final VoidCallback onRequestAnyway;

  const _DriverPanelContent({
    required this.nearbyDrivers,
    required this.otherActiveDrivers,
    required this.hasPickup,
    required this.bookingDriverId,
    required this.isRequestingAny,
    required this.isBookingLoading,
    required this.fareLabel,
    this.fareNote,
    required this.paymentMethod,
    required this.distanceLabelBuilder,
    required this.onBookDriver,
    required this.onRequestAnyway,
  });

  @override
  Widget build(BuildContext context) {
    final hasNearbyDrivers = nearbyDrivers.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _BookingCheckoutSummary(
            fareLabel: fareLabel,
            fareNote: fareNote,
            paymentMethod: paymentMethod,
          ),
          const SizedBox(height: 16),
          if (hasNearbyDrivers)
            _DriverListSection(
              title: 'Active drivers nearby',
              subtitle: hasPickup
                  ? 'Inside the wider booking geofence'
                  : 'Sorted by availability',
              drivers: nearbyDrivers,
              bookingDriverId: bookingDriverId,
              selectedPaymentMethod: paymentMethod,
              distanceLabelBuilder: distanceLabelBuilder,
              onBookDriver: onBookDriver,
            )
          else
            _NoDriversState(
              hasActiveDrivers: otherActiveDrivers.isNotEmpty,
              isBooking: isRequestingAny || isBookingLoading,
              selectedPaymentMethod: paymentMethod,
              onRequestAnyway: onRequestAnyway,
            ),
          if (otherActiveDrivers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _DriverListSection(
              title: hasNearbyDrivers
                  ? 'Other active drivers'
                  : 'Active drivers',
              subtitle: hasNearbyDrivers
                  ? 'Available but outside the booking geofence'
                  : 'Available verified drivers right now',
              drivers: otherActiveDrivers,
              bookingDriverId: bookingDriverId,
              selectedPaymentMethod: paymentMethod,
              distanceLabelBuilder: distanceLabelBuilder,
              onBookDriver: onBookDriver,
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverListSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AvailableDriver> drivers;
  final String? bookingDriverId;
  final PassengerPaymentMethod selectedPaymentMethod;
  final String Function(AvailableDriver driver) distanceLabelBuilder;
  final ValueChanged<AvailableDriver> onBookDriver;

  const _DriverListSection({
    required this.title,
    required this.subtitle,
    required this.drivers,
    required this.bookingDriverId,
    required this.selectedPaymentMethod,
    required this.distanceLabelBuilder,
    required this.onBookDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: MapTextStyles.title.copyWith(fontSize: 16)),
        const SizedBox(height: 3),
        Text(subtitle, style: MapTextStyles.body.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        for (final driver in drivers) ...<Widget>[
          _AvailableDriverCard(
            driver: driver,
            distanceLabel: distanceLabelBuilder(driver),
            selectedPaymentMethod: selectedPaymentMethod,
            isBooking: bookingDriverId == driver.driverId,
            onBook: () => onBookDriver(driver),
          ),
          if (driver != drivers.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BookingCheckoutSummary extends StatelessWidget {
  final String fareLabel;
  final String? fareNote;
  final PassengerPaymentMethod paymentMethod;

  const _BookingCheckoutSummary({
    required this.fareLabel,
    this.fareNote,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final fareValue = paymentMethod.usesOnlineCheckout
        ? '$fareLabel / cash only fallback'
        : fareLabel;

    final note = fareNote?.trim();

    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryValue(
                  icon: Icons.payments_rounded,
                  label: 'Fare',
                  value: fareValue,
                ),
              ),
              Container(width: 1, height: 42, color: PassengerUi.border),
              Expanded(
                child: _SummaryValue(
                  icon: paymentMethod.type.icon,
                  label: 'Payment',
                  value: paymentMethod.displayLabel,
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              note,
              style: MapTextStyles.body.copyWith(
                fontSize: 12,
                color: note.contains('applied')
                    ? PassengerUi.successText
                    : PassengerUi.body,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: PassengerUi.accentBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: MapTextStyles.body.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MapTextStyles.value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailableDriverCard extends StatelessWidget {
  final AvailableDriver driver;
  final String distanceLabel;
  final PassengerPaymentMethod selectedPaymentMethod;
  final bool isBooking;
  final VoidCallback onBook;

  const _AvailableDriverCard({
    required this.driver,
    required this.distanceLabel,
    required this.selectedPaymentMethod,
    required this.isBooking,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final forcesCash =
        selectedPaymentMethod.usesOnlineCheckout &&
        !driver.supportsOnlinePayments;

    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: FirebaseStorageImage(
                imageUrl: driver.profileImageUrl,
                fallback: Container(
                  color: PassengerUi.blueSoft,
                  alignment: Alignment.center,
                  child: Text(
                    driver.fullName.isEmpty
                        ? 'D'
                        : driver.fullName[0].toUpperCase(),
                    style: TextStyle(
                      color: PassengerUi.accentBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        driver.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MapTextStyles.title.copyWith(fontSize: 15),
                      ),
                    ),
                    if (driver.isVerified)
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: PassengerUi.successText,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: PassengerUi.highlightAmber,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      driver.ratingLabel,
                      style: MapTextStyles.body.copyWith(fontSize: 12.5),
                    ),
                    if (driver.reviewCount > 0) ...<Widget>[
                      const SizedBox(width: 4),
                      Text(
                        '(${driver.reviewCountLabel})',
                        style: MapTextStyles.body.copyWith(fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        distanceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MapTextStyles.body.copyWith(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    PassengerStatusChip(
                      label: forcesCash
                          ? 'Cash only'
                          : driver.supportsOnlinePayments
                          ? 'Online payments'
                          : 'Cash',
                      textColor: forcesCash
                          ? PassengerUi.primary
                          : driver.supportsOnlinePayments
                          ? PassengerUi.successText
                          : PassengerUi.body,
                      backgroundColor: forcesCash
                          ? PassengerUi.dangerSoft
                          : driver.supportsOnlinePayments
                          ? PassengerUi.successBackground
                          : PassengerUi.mutedSurface,
                    ),
                    if (driver.displayBadge.isNotEmpty)
                      PassengerStatusChip(
                        label: driver.displayBadge,
                        textColor: driver.ratingRank == null
                            ? PassengerUi.accentBlue
                            : PassengerUi.highlightAmber,
                        backgroundColor: driver.ratingRank == null
                            ? PassengerUi.blueSoft
                            : PassengerUi.warningSoft,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: isBooking ? null : onBook,
            child: isBooking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(forcesCash ? 'Cash Only' : 'Book Now'),
          ),
        ],
      ),
    );
  }
}

class _NoDriversState extends StatelessWidget {
  final bool hasActiveDrivers;
  final bool isBooking;
  final PassengerPaymentMethod selectedPaymentMethod;
  final VoidCallback onRequestAnyway;

  const _NoDriversState({
    required this.hasActiveDrivers,
    required this.isBooking,
    required this.selectedPaymentMethod,
    required this.onRequestAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PassengerEmptyState(
            icon: Icons.two_wheeler_outlined,
            title: 'No active drivers nearby',
            description: hasActiveDrivers
                ? 'You can request anyway or choose an active driver below.'
                : 'You can still create a request. It will appear when a verified driver goes active.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBooking ? null : onRequestAnyway,
              icon: const Icon(Icons.radar_rounded),
              label: Text(
                isBooking
                    ? 'Requesting...'
                    : selectedPaymentMethod.usesOnlineCheckout
                    ? 'Request Anyway - Cash'
                    : 'Request Anyway',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedDestinationRow extends StatelessWidget {
  final List<PassengerQuickDestination> destinations;
  final bool isLoading;
  final ValueChanged<PassengerQuickDestination> onTap;

  const _SavedDestinationRow({
    required this.destinations,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 68,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleDestinations = destinations.take(4).toList();
        final isTight = constraints.maxWidth < 380;

        if (isTight) {
          final itemWidth = (constraints.maxWidth - 10) / 2;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: visibleDestinations
                .map(
                  (destination) => SizedBox(
                    width: itemWidth,
                    child: _SavedDestinationButton(
                      destination: destination,
                      onTap: () => onTap(destination),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: visibleDestinations
              .asMap()
              .entries
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == visibleDestinations.length - 1
                          ? 0
                          : 10,
                    ),
                    child: _SavedDestinationButton(
                      destination: entry.value,
                      onTap: () => onTap(entry.value),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SavedDestinationButton extends StatelessWidget {
  final PassengerQuickDestination destination;
  final VoidCallback onTap;

  const _SavedDestinationButton({
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: PassengerUi.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      ),
      child: Column(
        children: <Widget>[
          Icon(destination.icon, color: destination.accentColor),
          const SizedBox(height: 6),
          Text(
            destination.label,
            style: MapTextStyles.value.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineNotice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: PassengerUi.highlightAmber),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: MapTextStyles.body)),
        ],
      ),
    );
  }
}
