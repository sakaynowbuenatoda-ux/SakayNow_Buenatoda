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
          TextButton.icon(
            onPressed: () => _editDestination(),
            icon: Icon(
              Icons.add_circle_rounded,
              color: PassengerUi.secondary,
              size: 24,
            ),
            label: Text(
              'Add',
              style: TextStyle(
                color: PassengerUi.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.controller.destinations.isEmpty) {
            return ListView(
              padding: PassengerUi.pagePadding(context),
              children: const <Widget>[
                PassengerEmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'No quick destinations saved yet',
                  description:
                      'Tap Add to save places you use often for faster booking.',
                ),
              ],
            );
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
    final saved = await showDialog<PassengerQuickDestination>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _QuickDestinationFormDialog(
        destination: destination,
        onPickLocation: (pickerContext) => _pickLocation(
          destination: destination,
          title: 'Pin Destination',
          pickerContext: pickerContext,
        ),
      ),
    );

    if (!mounted || saved == null) {
      return;
    }

    await _saveDestination(saved);
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

    await _saveDestination(
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
    BuildContext? pickerContext,
  }) async {
    final pickerTarget = await _quickDestinationPickerTarget(destination);
    if (!mounted) {
      return null;
    }

    final selected = await showModalBottomSheet<LocationPinPickResult>(
      context: pickerContext ?? context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
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
      final address = await _placesService.reverseGeocode(location);
      return RideLocation(
        address: address,
        name: 'Pinned location',
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } on Exception {
      return RideLocation(
        address:
            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
        name: 'Pinned location',
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

  Future<void> _saveDestination(PassengerQuickDestination destination) async {
    try {
      await widget.controller.upsert(destination);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save destination: $error')),
      );
    }
  }
}

class _QuickDestinationFormDialog extends StatefulWidget {
  final PassengerQuickDestination? destination;
  final Future<RideLocation?> Function(BuildContext context) onPickLocation;

  const _QuickDestinationFormDialog({
    required this.destination,
    required this.onPickLocation,
  });

  @override
  State<_QuickDestinationFormDialog> createState() =>
      _QuickDestinationFormDialogState();
}

class _QuickDestinationFormDialogState
    extends State<_QuickDestinationFormDialog> {
  late final TextEditingController _labelController;
  RideLocation? _selectedLocation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.destination?.label ?? '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PassengerUi.border),
            boxShadow: PassengerUi.cardShadow,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.destination == null
                      ? 'Add Destination'
                      : 'Edit Destination',
                  style: MapTextStyles.title,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _labelController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.push_pin_outlined),
                    label: Text(
                      _selectedLocation?.address ??
                          widget.destination?.address ??
                          'Set location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: PassengerUi.bodyText.copyWith(
                      color: PassengerUi.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await widget.onPickLocation(context);
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedLocation = picked;
      _errorMessage = null;
    });
  }

  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _errorMessage = 'Enter a destination label.');
      return;
    }

    if (_selectedLocation == null &&
        widget.destination?.hasCoordinates != true) {
      setState(() => _errorMessage = 'Set a pin before saving.');
      return;
    }

    final location = _selectedLocation;
    final existing = widget.destination;

    Navigator.of(context).pop(
      PassengerQuickDestination(
        id: existing?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        address: location?.address ?? existing?.address,
        icon: existing?.icon ?? Icons.place_rounded,
        accentColor: existing?.accentColor ?? PassengerUi.accentBlue,
        backgroundColor: existing?.backgroundColor ?? PassengerUi.blueSoft,
        latitude: location?.latitude ?? existing?.latitude,
        longitude: location?.longitude ?? existing?.longitude,
        isDefault: existing?.isDefault ?? false,
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
