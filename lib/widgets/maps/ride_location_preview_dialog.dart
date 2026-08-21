import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/ride_location.dart';
import '../../models/route_result.dart';
import '../../services/google_directions_service.dart';
import '../passenger_widgets/passenger_ui.dart';
import 'sakay_google_map.dart';

Future<void> showRideLocationPreviewDialog({
  required BuildContext context,
  required RideLocation pickupLocation,
  required RideLocation dropoffLocation,
  RouteResult? route,
}) {
  if (pickupLocation.latLng == null || dropoffLocation.latLng == null) {
    return Future<void>.value();
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => RideLocationPreviewDialog(
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      route: route,
    ),
  );
}

class RideLocationPreviewButton extends StatelessWidget {
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  final RouteResult? route;
  final String tooltip;
  final Color? color;
  final double dimension;
  final double iconSize;

  const RideLocationPreviewButton({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.route,
    this.tooltip = 'Preview route',
    this.color,
    this.dimension = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (pickupLocation.latLng == null || dropoffLocation.latLng == null) {
      return const SizedBox.shrink();
    }

    final foreground = color ?? PassengerUi.accentBlue;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints.tightFor(
          width: dimension,
          height: dimension,
        ),
        style: IconButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: foreground.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => showRideLocationPreviewDialog(
          context: context,
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          route: route,
        ),
        icon: Icon(Icons.map_rounded, size: iconSize),
      ),
    );
  }
}

class RideLocationPreviewDialog extends StatefulWidget {
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  final RouteResult? route;

  const RideLocationPreviewDialog({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.route,
  });

  @override
  State<RideLocationPreviewDialog> createState() =>
      _RideLocationPreviewDialogState();
}

class _RideLocationPreviewDialogState extends State<RideLocationPreviewDialog> {
  MapType _mapType = MapType.normal;
  RouteResult? _route;
  bool _isLoadingRoute = false;
  bool _couldNotLoadRoute = false;

  @override
  void initState() {
    super.initState();
    final pickup = widget.pickupLocation.latLng!;
    final dropoff = widget.dropoffLocation.latLng!;
    final savedRoute =
        routeMatchesPreviewTrip(widget.route, pickup: pickup, dropoff: dropoff)
        ? widget.route
        : null;

    // Keep the route used for the original ETA when it is valid. If historical
    // geometry is missing or corrupt, load a replacement road route.
    _route = savedRoute;
    if (savedRoute == null) {
      _loadRoadRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickupLocation.latLng!;
    final dropoff = widget.dropoffLocation.latLng!;
    final routePoints = routePreviewPolylinePoints(_route);
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(size.width - 32, 620.0);
    final dialogHeight = math.min(math.max(size.height - 48, 320.0), 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      backgroundColor: PassengerUi.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Route preview',
                      style: PassengerUi.cardTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: SakayGoogleMap(
                          initialCameraTarget: pickup,
                          bounds: _boundsFor(
                            pickup,
                            dropoff,
                            routePoints: routePoints,
                          ),
                          markers: _markersFor(pickup, dropoff),
                          polylines: _polylinesFor(routePoints),
                          mapType: _mapType,
                        ),
                      ),
                      if (_isLoadingRoute)
                        const Positioned.fill(child: _RouteLoadingOverlay()),
                      if (_couldNotLoadRoute)
                        const Positioned.fill(
                          child: _RouteUnavailableOverlay(),
                        ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _PreviewMapTypeToggle(
                          mapType: _mapType,
                          onChanged: (value) => setState(() {
                            _mapType = value;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: <Widget>[
                  _LocationSummaryLine(
                    icon: Icons.my_location_rounded,
                    iconColor: PassengerUi.secondary,
                    label: 'Pickup',
                    value: widget.pickupLocation.publicDisplayLabel,
                  ),
                  const SizedBox(height: 8),
                  _LocationSummaryLine(
                    icon: Icons.location_on_rounded,
                    iconColor: PassengerUi.primary,
                    label: 'Drop-off',
                    value: widget.dropoffLocation.publicDisplayLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<Marker> _markersFor(LatLng pickup, LatLng dropoff) {
    return <Marker>{
      Marker(
        markerId: const MarkerId('preview_pickup'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup',
          snippet: widget.pickupLocation.publicDisplayLabel,
        ),
      ),
      Marker(
        markerId: const MarkerId('preview_dropoff'),
        position: dropoff,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Drop-off',
          snippet: widget.dropoffLocation.publicDisplayLabel,
        ),
      ),
    };
  }

  Future<void> _loadRoadRoute() async {
    final pickup = widget.pickupLocation.latLng;
    final dropoff = widget.dropoffLocation.latLng;
    if (pickup == null || dropoff == null) {
      return;
    }

    setState(() => _isLoadingRoute = true);
    try {
      final route = await GoogleDirectionsService().fetchRoute(
        origin: pickup,
        destination: dropoff,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        final matchesTrip = routeMatchesPreviewTrip(
          route,
          pickup: pickup,
          dropoff: dropoff,
        );
        _route = matchesTrip ? route : null;
        _couldNotLoadRoute = !matchesTrip;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() => _couldNotLoadRoute = true);
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  Set<Polyline> _polylinesFor(List<LatLng> routePoints) {
    if (routePoints.isEmpty) {
      return const <Polyline>{};
    }

    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('preview_route_line'),
        points: routePoints,
        width: 4,
        color: PassengerUi.accentBlue.withValues(alpha: 0.75),
      ),
    };
  }

  LatLngBounds _boundsFor(
    LatLng pickup,
    LatLng dropoff, {
    required List<LatLng> routePoints,
  }) {
    // Derive the viewport from the geometry that is actually drawn. Stored
    // bounds may predate corrected pickup/drop-off coordinates.
    final points = <LatLng>[pickup, dropoff, ...routePoints];
    return LatLngBounds(
      southwest: LatLng(
        points.map((point) => point.latitude).reduce(math.min),
        points.map((point) => point.longitude).reduce(math.min),
      ),
      northeast: LatLng(
        points.map((point) => point.latitude).reduce(math.max),
        points.map((point) => point.longitude).reduce(math.max),
      ),
    );
  }
}

/// Returns only road geometry. Two points represent the former straight-line
/// fallback, never a route that should be presented as a recommended journey.
List<LatLng> routePreviewPolylinePoints(RouteResult? route) {
  if (!_hasRoadRoute(route)) {
    return const <LatLng>[];
  }

  return List<LatLng>.unmodifiable(route!.polylinePoints);
}

bool _hasRoadRoute(RouteResult? route) =>
    route != null && route.polylinePoints.length > 2;

/// Rejects saved geometry that belongs to another trip or does not terminate
/// near the selected pickup and drop-off. Google may snap endpoints to a road,
/// so a small tolerance is intentional.
bool routeMatchesPreviewTrip(
  RouteResult? route, {
  required LatLng pickup,
  required LatLng dropoff,
}) {
  if (!_hasRoadRoute(route)) {
    return false;
  }

  final points = route!.polylinePoints;
  if (points.any((point) => !_isValidCoordinate(point))) {
    return false;
  }

  const endpointToleranceMeters = 750.0;
  if (_distanceMeters(points.first, pickup) > endpointToleranceMeters ||
      _distanceMeters(points.last, dropoff) > endpointToleranceMeters) {
    return false;
  }

  final directDistanceMeters = _distanceMeters(pickup, dropoff);
  final storedDistanceMeters = route.distanceMeters.toDouble();
  final expectedDistanceMeters = math.max(
    directDistanceMeters,
    storedDistanceMeters,
  );
  final maximumPlausibleGeometryMeters = math.max(
    3000.0,
    expectedDistanceMeters * 2.5,
  );

  var geometryDistanceMeters = 0.0;
  for (var index = 1; index < points.length; index += 1) {
    geometryDistanceMeters += _distanceMeters(points[index - 1], points[index]);
    if (geometryDistanceMeters > maximumPlausibleGeometryMeters) {
      return false;
    }
  }

  return true;
}

bool _isValidCoordinate(LatLng point) {
  return point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;
}

double _distanceMeters(LatLng a, LatLng b) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _toRadians(b.latitude - a.latitude);
  final longitudeDelta = _toRadians(b.longitude - a.longitude);
  final aLatitude = _toRadians(a.latitude);
  final bLatitude = _toRadians(b.latitude);
  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(aLatitude) *
          math.cos(bLatitude) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

class _RouteLoadingOverlay extends StatelessWidget {
  const _RouteLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Loading recommended route'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteUnavailableOverlay extends StatelessWidget {
  const _RouteUnavailableOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'The recommended road route is unavailable for this trip.',
            textAlign: TextAlign.center,
            style: PassengerUi.valueText.copyWith(color: PassengerUi.surface),
          ),
        ),
      ),
    );
  }
}

class _PreviewMapTypeToggle extends StatelessWidget {
  final MapType mapType;
  final ValueChanged<MapType> onChanged;

  const _PreviewMapTypeToggle({required this.mapType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(
              alpha: PassengerUi.isDarkMode ? 0.28 : 0.15,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PreviewMapTypeButton(
              tooltip: 'Default',
              icon: Icons.map_rounded,
              isSelected: mapType == MapType.normal,
              onPressed: () => onChanged(MapType.normal),
            ),
            _PreviewMapTypeButton(
              tooltip: 'Satellite',
              icon: Icons.satellite_alt_rounded,
              isSelected: mapType == MapType.hybrid,
              onPressed: () => onChanged(MapType.hybrid),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMapTypeButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _PreviewMapTypeButton({
    required this.tooltip,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? PassengerUi.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          foregroundColor: isSelected ? PassengerUi.primary : PassengerUi.body,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class _LocationSummaryLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _LocationSummaryLine({
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
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
              children: <InlineSpan>[
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: PassengerUi.valueText.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
