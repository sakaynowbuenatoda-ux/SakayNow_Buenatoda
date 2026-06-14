import 'package:flutter/material.dart';

import '../../core/preferences/app_preferences_controller.dart';
import '../passenger_widgets/passenger_ui.dart';

class MapTypeToggle extends StatelessWidget {
  const MapTypeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppPreferencesController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
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
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MapTypeButton(
                  tooltip: 'Default',
                  icon: Icons.map_rounded,
                  isSelected:
                      controller.mapTypePreference ==
                      AppMapTypePreference.normal,
                  onPressed: () => controller.setMapTypePreference(
                    AppMapTypePreference.normal,
                  ),
                ),
                _MapTypeButton(
                  tooltip: 'Satellite with labels',
                  icon: Icons.satellite_alt_rounded,
                  isSelected:
                      controller.mapTypePreference ==
                      AppMapTypePreference.satellite,
                  onPressed: () => controller.setMapTypePreference(
                    AppMapTypePreference.satellite,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapTypeButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _MapTypeButton({
    required this.tooltip,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = PassengerUi.primary;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? selectedColor.withValues(alpha: 0.12)
              : Colors.transparent,
          foregroundColor: isSelected ? selectedColor : PassengerUi.body,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
