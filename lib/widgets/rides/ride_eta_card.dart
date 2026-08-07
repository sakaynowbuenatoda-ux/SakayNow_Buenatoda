import 'package:flutter/material.dart';

import '../../models/ride.dart';
import '../../models/ride_eta_presentation.dart';
import '../maps/map_text_styles.dart';
import '../passenger_widgets/passenger_ui.dart';

class RideEtaCard extends StatelessWidget {
  final Ride ride;

  const RideEtaCard({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final presentation = RideEtaPresentation.forRide(ride);

    return PassengerSurfaceCard(
      key: ValueKey<String>('ride-eta-${ride.status.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(presentation.title, style: MapTextStyles.value),
          const SizedBox(height: 4),
          Text(presentation.description, style: MapTextStyles.body),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _RideMetricTile(
                icon: Icons.access_time_rounded,
                label: presentation.etaLabel,
                value: presentation.etaValue,
              ),
              Container(width: 1, height: 42, color: PassengerUi.border),
              _RideMetricTile(
                icon: Icons.social_distance_rounded,
                label: presentation.distanceLabel,
                value: presentation.distanceValue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RideMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RideMetricTile({
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
