import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerQuickDestinationsSection extends StatelessWidget {
  final List<PassengerQuickDestination> destinations;
  final VoidCallback onSeeAllTap;
  final ValueChanged<PassengerQuickDestination> onDestinationTap;

  const PassengerQuickDestinationsSection({
    super.key,
    required this.destinations,
    required this.onSeeAllTap,
    required this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PassengerSectionHeader(
          title: 'Quick Destinations',
          actionLabel: 'See all',
          onActionTap: onSeeAllTap,
        ),
        const SizedBox(height: 12),
        Row(
          children: destinations
              .asMap()
              .entries
              .map(
                (MapEntry<int, PassengerQuickDestination> entry) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == destinations.length - 1 ? 0 : 10,
                    ),
                    child: PassengerQuickDestinationCard(
                      destination: entry.value,
                      onTap: () => onDestinationTap(entry.value),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class PassengerQuickDestinationCard extends StatelessWidget {
  final PassengerQuickDestination destination;
  final VoidCallback onTap;

  const PassengerQuickDestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 126,
        decoration: BoxDecoration(
          color: PassengerUi.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PassengerUi.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: destination.backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                destination.icon,
                color: destination.accentColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              destination.label,
              style: PassengerUi.cardTitle.copyWith(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                destination.address,
                style: PassengerUi.bodyText.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
