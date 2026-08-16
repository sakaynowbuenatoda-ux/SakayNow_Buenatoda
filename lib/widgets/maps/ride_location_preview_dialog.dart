import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/ride_location.dart';
import '../passenger_widgets/passenger_ui.dart';
import 'sakay_google_map.dart';

Future<void> showRideLocationPreviewDialog({
  required BuildContext context,
  required RideLocation pickupLocation,
  required RideLocation dropoffLocation,
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
    ),
  );
}

class RideLocationPreviewButton extends StatelessWidget {
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  final String tooltip;
  final Color? color;
  final double dimension;
  final double iconSize;

  const RideLocationPreviewButton({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
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
        ),
        icon: Icon(Icons.map_rounded, size: iconSize),
      ),
    );
  }
}

class RideLocationPreviewDialog extends StatefulWidget {
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;

  const RideLocationPreviewDialog({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
  });

  @override
  State<RideLocationPreviewDialog> createState() =>
      _RideLocationPreviewDialogState();
}

class _RideLocationPreviewDialogState extends State<RideLocationPreviewDialog> {
  MapType _mapType = MapType.normal;

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickupLocation.latLng!;
    final dropoff = widget.dropoffLocation.latLng!;
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
                          bounds: _boundsFor(pickup, dropoff),
                          markers: _markersFor(pickup, dropoff),
                          polylines: _polylinesFor(pickup, dropoff),
                          mapType: _mapType,
                        ),
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

  Set<Polyline> _polylinesFor(LatLng pickup, LatLng dropoff) {
    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('preview_route_line'),
        points: <LatLng>[pickup, dropoff],
        width: 4,
        color: PassengerUi.accentBlue.withValues(alpha: 0.75),
      ),
    };
  }

  LatLngBounds _boundsFor(LatLng pickup, LatLng dropoff) {
    return LatLngBounds(
      southwest: LatLng(
        math.min(pickup.latitude, dropoff.latitude),
        math.min(pickup.longitude, dropoff.longitude),
      ),
      northeast: LatLng(
        math.max(pickup.latitude, dropoff.latitude),
        math.max(pickup.longitude, dropoff.longitude),
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
