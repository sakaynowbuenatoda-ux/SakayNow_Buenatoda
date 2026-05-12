import 'package:flutter/material.dart';

import '../../models/distance_matrix_result.dart';
import '../../models/route_result.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'map_text_styles.dart';

class RouteSummaryCard extends StatelessWidget {
  final RouteResult? route;
  final DistanceMatrixResult? estimate;
  final bool isLoading;
  final String? errorMessage;

  const RouteSummaryCard({
    super.key,
    required this.route,
    required this.estimate,
    required this.isLoading,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return PassengerSurfaceCard(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: PassengerUi.accentBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Calculating route...', style: MapTextStyles.body),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return PassengerSurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: PassengerUi.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(errorMessage!, style: MapTextStyles.body)),
          ],
        ),
      );
    }

    final activeRoute = route;
    if (activeRoute == null) {
      return PassengerSurfaceCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.route_rounded, color: PassengerUi.accentBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select pickup and drop-off places to preview distance and ETA.',
                style: MapTextStyles.body,
              ),
            ),
          ],
        ),
      );
    }

    final activeEstimate = estimate;
    final distanceText = activeEstimate?.distanceText.isNotEmpty == true
        ? activeEstimate!.distanceText
        : activeRoute.distanceText;
    final durationText = activeEstimate?.durationText.isNotEmpty == true
        ? activeEstimate!.durationText
        : activeRoute.durationText;

    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          _MetricTile(
            icon: Icons.route_rounded,
            label: 'Distance',
            value: distanceText.isEmpty ? 'Calculating' : distanceText,
          ),
          Container(width: 1, height: 44, color: PassengerUi.border),
          _MetricTile(
            icon: Icons.access_time_rounded,
            label: 'ETA',
            value: durationText.isEmpty ? 'Calculating' : durationText,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: <Widget>[
          Icon(icon, color: PassengerUi.accentBlue),
          const SizedBox(width: 10),
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
      ),
    );
  }
}
