import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../core/preferences/app_preferences_controller.dart';
import '../../models/ride_location.dart';
import '../../services/google_places_service.dart';
import '../passenger_widgets/passenger_ui.dart';
import 'map_text_styles.dart';
import 'map_type_toggle.dart';
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
  List<RideLocation> _nearbyPlaces = <RideLocation>[];
  String? _manualAddress;
  bool _isResolvingPlace = false;
  int _resolveToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectManualPin(_selected);
      }
    });
  }

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
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: AppPreferencesController.instance,
                    builder: (context, _) {
                      return SakayGoogleMap(
                        initialCameraTarget: _cameraTarget,
                        markers: _markers,
                        mapType:
                            AppPreferencesController.instance.googleMapType,
                        myLocationEnabled: widget.myLocationEnabled,
                        zoomControlsEnabled: true,
                        autoMoveCamera: false,
                        onTap: _selectFromMapTap,
                      );
                    },
                  ),
                ),
                const Positioned(top: 12, right: 12, child: MapTypeToggle()),
              ],
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
                  nearbyPlaces: _nearbyPlaces,
                  manualAddress: _manualAddress,
                  isResolving: _isResolvingPlace,
                  onUseNearbyPlace: _useNearbyGooglePlace,
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

  Future<void> _selectFromMapTap(LatLng location) {
    return _selectManualPin(location);
  }

  Future<void> _selectManualPin(LatLng location) async {
    final token = ++_resolveToken;
    setState(() {
      _selected = location;
      _cameraTarget = location;
      _googlePlace = null;
      _nearbyPlaces = <RideLocation>[];
      _manualAddress = null;
      _isResolvingPlace = true;
    });

    String? address;
    try {
      address = await _placesService.reverseGeocode(location);
    } on Exception {
      address = null;
    }

    var knownPlaces = <RideLocation>[];
    try {
      knownPlaces = await _placesService.nearbyKnownPlaces(location);
    } on Exception {
      knownPlaces = <RideLocation>[];
    }

    if (!mounted || token != _resolveToken) {
      return;
    }

    setState(() {
      _nearbyPlaces = knownPlaces;
      _manualAddress = _cleanAddress(address);
      _isResolvingPlace = false;
    });
  }

  void _useNearbyGooglePlace(RideLocation place) {
    final placeLocation = place.latLng;
    if (placeLocation == null) {
      return;
    }

    ++_resolveToken;
    setState(() {
      _selected = placeLocation;
      _cameraTarget = placeLocation;
      _googlePlace = place;
      _manualAddress = place.address;
      _isResolvingPlace = false;
    });
  }

  String? _cleanAddress(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _saveSelection() {
    Navigator.of(context).pop(
      LocationPinPickResult(location: _selected, googlePlace: _googlePlace),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final RideLocation? place;
  final List<RideLocation> nearbyPlaces;
  final String? manualAddress;
  final bool isResolving;
  final ValueChanged<RideLocation> onUseNearbyPlace;

  const _SelectionSummary({
    required this.place,
    required this.nearbyPlaces,
    required this.manualAddress,
    required this.isResolving,
    required this.onUseNearbyPlace,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPlace = place;
    final title = isResolving
        ? 'Checking map details...'
        : selectedPlace?.name ?? 'Manual pinned location';
    final visibleNearbyPlaces = selectedPlace == null
        ? nearbyPlaces.take(4).toList(growable: false)
        : <RideLocation>[];
    final subtitle = selectedPlace != null
        ? selectedPlace.address
        : manualAddress ??
              'Exact pin saved at the selected map point. Drag to adjust.';

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
                if (visibleNearbyPlaces.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nearby labels',
                      style: MapTextStyles.value.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: visibleNearbyPlaces
                        .map(
                          (nearby) => ActionChip(
                            avatar: const Icon(Icons.place_rounded, size: 16),
                            label: Text(
                              nearby.name ?? nearby.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => onUseNearbyPlace(nearby),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
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
