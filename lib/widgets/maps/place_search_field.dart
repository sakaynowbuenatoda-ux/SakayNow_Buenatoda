import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/map_config.dart';
import '../../models/place_prediction.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'map_text_styles.dart';

class PlaceSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData icon;
  final Color iconColor;
  final bool isLoading;
  final List<PlacePrediction> predictions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PlacePrediction> onPredictionSelected;
  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onPickFromMap;

  const PlaceSearchField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    required this.icon,
    required this.iconColor,
    required this.isLoading,
    required this.predictions,
    required this.onSearchChanged,
    required this.onPredictionSelected,
    this.onUseCurrentLocation,
    this.onPickFromMap,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        PassengerSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: <Widget>[
              Icon(widget.icon, color: widget.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  textInputAction: TextInputAction.search,
                  onChanged: _handleChanged,
                  onSubmitted: _handleSubmitted,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    labelStyle: MapTextStyles.body,
                  ),
                ),
              ),
              if (widget.isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.iconColor,
                  ),
                )
              else ...<Widget>[
                if (widget.onPickFromMap != null)
                  IconButton(
                    tooltip: 'Pin on map',
                    onPressed: widget.onPickFromMap,
                    icon: const Icon(Icons.push_pin_outlined),
                    color: PassengerUi.primary,
                  ),
                if (widget.onUseCurrentLocation != null)
                  IconButton(
                    tooltip: 'Use current location',
                    onPressed: widget.onUseCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    color: PassengerUi.accentBlue,
                  ),
              ],
            ],
          ),
        ),
        if (widget.predictions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          PassengerSurfaceCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.predictions.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: PassengerUi.border),
              itemBuilder: (context, index) {
                final prediction = widget.predictions[index];

                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.place_rounded,
                    color: PassengerUi.accentBlue,
                  ),
                  title: Text(
                    prediction.mainText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MapTextStyles.value,
                  ),
                  subtitle: prediction.secondaryText.isEmpty
                      ? null
                      : Text(
                          prediction.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MapTextStyles.body.copyWith(fontSize: 12),
                        ),
                  onTap: () => widget.onPredictionSelected(prediction),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _handleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: MapConfig.placesSearchDebounceMs),
      () => widget.onSearchChanged(value),
    );
  }

  void _handleSubmitted(String value) {
    _debounce?.cancel();
    widget.onSearchChanged(value);
  }
}
