import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';
import '../../controllers/quick_destinations_controller.dart';
import '../../models/ride_location.dart';
import '../../services/google_places_service.dart';
import '../../services/location_service.dart';
import '../../widgets/maps/location_pin_picker_sheet.dart';
import '../../widgets/maps/map_text_styles.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerQuickDestinationsPage extends StatefulWidget {
  final QuickDestinationsController controller;

  const PassengerQuickDestinationsPage({super.key, required this.controller});

  @override
  State<PassengerQuickDestinationsPage> createState() =>
      _PassengerQuickDestinationsPageState();
}

class _PassengerQuickDestinationsPageState
    extends State<PassengerQuickDestinationsPage> {
  final GooglePlacesService _placesService = GooglePlacesService();
  final LocationService _locationService = const LocationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.background,
        surfaceTintColor: PassengerUi.background,
        title: Text('Quick Destinations', style: MapTextStyles.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add destination',
            onPressed: () => _editDestination(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            padding: PassengerUi.pagePadding(context),
            itemCount: widget.controller.destinations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final destination = widget.controller.destinations[index];
              return PassengerSurfaceCard(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: destination.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        destination.icon,
                        color: destination.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(destination.label, style: MapTextStyles.title),
                          const SizedBox(height: 3),
                          Text(
                            destination.address?.trim().isNotEmpty == true
                                ? destination.address!
                                : 'Set location',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MapTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Set pin',
                      onPressed: () => _setDestinationLocation(destination),
                      icon: const Icon(Icons.push_pin_outlined),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editDestination(destination: destination);
                        } else if (value == 'remove') {
                          widget.controller.remove(destination);
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Text(
                            destination.isDefault ? 'Clear' : 'Remove',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editDestination({
    PassengerQuickDestination? destination,
  }) async {
    final labelController = TextEditingController(text: destination?.label);
    RideLocation? selectedLocation;

    final saved = await showModalBottomSheet<PassengerQuickDestination>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return Container(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottomInset),
              decoration: BoxDecoration(
                color: PassengerUi.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    destination == null
                        ? 'Add Destination'
                        : 'Edit Destination',
                    style: MapTextStyles.title,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickLocation(
                        destination: destination,
                        title: 'Pin Destination',
                      );
                      if (picked != null) {
                        setSheetState(() => selectedLocation = picked);
                      }
                    },
                    icon: const Icon(Icons.push_pin_outlined),
                    label: Text(
                      selectedLocation?.address ??
                          destination?.address ??
                          'Set location',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final label = labelController.text.trim();
                        final location = selectedLocation;
                        final existing = destination;
                        if (label.isEmpty) {
                          return;
                        }

                        Navigator.of(context).pop(
                          PassengerQuickDestination(
                            id:
                                existing?.id ??
                                'custom_${DateTime.now().microsecondsSinceEpoch}',
                            label: label,
                            address: location?.address ?? existing?.address,
                            icon: existing?.icon ?? Icons.place_rounded,
                            accentColor:
                                existing?.accentColor ?? PassengerUi.accentBlue,
                            backgroundColor:
                                existing?.backgroundColor ??
                                PassengerUi.blueSoft,
                            latitude: location?.latitude ?? existing?.latitude,
                            longitude:
                                location?.longitude ?? existing?.longitude,
                            isDefault: existing?.isDefault ?? false,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    labelController.dispose();

    if (saved != null) {
      await widget.controller.upsert(saved);
    }
  }

  Future<void> _setDestinationLocation(
    PassengerQuickDestination destination,
  ) async {
    final picked = await _pickLocation(
      destination: destination,
      title: 'Set ${destination.label}',
    );
    if (picked == null) {
      return;
    }

    await widget.controller.upsert(
      destination.copyWith(
        address: _locationDisplayText(picked),
        latitude: picked.latitude,
        longitude: picked.longitude,
      ),
    );
  }

  Future<RideLocation?> _pickLocation({
    PassengerQuickDestination? destination,
    required String title,
  }) async {
    final pickerTarget = await _quickDestinationPickerTarget(destination);
    if (!mounted) {
      return null;
    }

    final selected = await showModalBottomSheet<LocationPinPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPinPickerSheet(
        title: title,
        actionLabel: 'Save Location',
        initialTarget: pickerTarget.location,
        accentColor: destination?.accentColor ?? PassengerUi.accentBlue,
        myLocationEnabled: pickerTarget.usesCurrentLocation,
      ),
    );

    if (selected == null) {
      return null;
    }

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
    PassengerQuickDestination? destination,
  ) async {
    if (destination?.hasCoordinates == true) {
      return _PickerTarget(
        location: LatLng(destination!.latitude!, destination.longitude!),
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
    final name = location.name?.trim();
    if (name != null && name.isNotEmpty && name != 'Pinned location') {
      return name;
    }

    return location.address;
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
