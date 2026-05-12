import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../models/ride_location.dart';
import '../../services/google_places_service.dart';
import '../passenger_widgets/passenger_ui.dart';
import 'map_text_styles.dart';
import 'sakay_google_map.dart';

class LocationPinPickResult {
  final LatLng location;
  final RideLocation? googlePlace;

  const LocationPinPickResult({required this.location, this.googlePlace});

  bool get usesGooglePlace => googlePlace != null;
}

class LocationPinPickerSheet extends StatefulWidget {
  final String title;
  final String actionLabel;
  final LatLng initialTarget;
  final Color accentColor;
  final bool myLocationEnabled;

  const LocationPinPickerSheet({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.initialTarget,
    required this.accentColor,
    this.myLocationEnabled = false,
  });

  @override
  State<LocationPinPickerSheet> createState() => _LocationPinPickerSheetState();
}

class _LocationPinPickerSheetState extends State<LocationPinPickerSheet> {
  final GooglePlacesService _placesService = GooglePlacesService();
  late LatLng _selected = widget.initialTarget;
  late LatLng _cameraTarget = widget.initialTarget;
  RideLocation? _googlePlace;
  bool _isResolvingPlace = false;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: PassengerUi.border,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(widget.title, style: MapTextStyles.title)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SakayGoogleMap(
              initialCameraTarget: _cameraTarget,
              markers: _markers,
              myLocationEnabled: widget.myLocationEnabled,
              zoomControlsEnabled: true,
              autoMoveCamera: false,
              onTap: _selectFromMapTap,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              18 + PassengerUi.pageBottomInset(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SelectionSummary(
                  place: _googlePlace,
                  isResolving: _isResolvingPlace,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResolvingPlace ? null : _saveSelection,
                    icon: _isResolvingPlace
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(widget.actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> get _markers {
    if (_googlePlace != null) {
      return const <Marker>{};
    }

    return <Marker>{
      Marker(
        markerId: const MarkerId('selected_pin'),
        position: _selected,
        draggable: true,
        onDragEnd: _selectManualPin,
        icon: widget.accentColor == PassengerUi.secondary
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarker,
      ),
    };
  }

  Future<void> _selectFromMapTap(LatLng location) async {
    setState(() {
      _selected = location;
      _cameraTarget = location;
      _googlePlace = null;
      _isResolvingPlace = true;
    });

    RideLocation? knownPlace;
    try {
      knownPlace = await _placesService.nearestKnownPlace(location);
    } on Exception {
      knownPlace = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _googlePlace = knownPlace;
      _selected = knownPlace?.latLng ?? location;
      _cameraTarget = _selected;
      _isResolvingPlace = false;
    });
  }

  void _selectManualPin(LatLng location) {
    setState(() {
      _selected = location;
      _cameraTarget = location;
      _googlePlace = null;
      _isResolvingPlace = false;
    });
  }

  void _saveSelection() {
    Navigator.of(context).pop(
      LocationPinPickResult(location: _selected, googlePlace: _googlePlace),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final RideLocation? place;
  final bool isResolving;

  const _SelectionSummary({required this.place, required this.isResolving});

  @override
  Widget build(BuildContext context) {
    final selectedPlace = place;
    final title = isResolving
        ? 'Checking Google places...'
        : selectedPlace?.name ?? 'Manual pinned location';
    final subtitle = selectedPlace == null
        ? 'Tap a Google place label to use its name, or drag the pin manually.'
        : 'Using Google place pin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            selectedPlace == null
                ? Icons.location_on_rounded
                : Icons.place_rounded,
            color: selectedPlace == null
                ? PassengerUi.primary
                : PassengerUi.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.value.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.body.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

LatLng defaultPinPickerTarget(LatLng? preferred) {
  return preferred ?? MapConfig.buenavistaCenter;
}
