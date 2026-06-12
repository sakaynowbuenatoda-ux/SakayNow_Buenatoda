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
        if (destinations.isEmpty)
          InkWell(
            borderRadius: PassengerUi.cardRadius,
            onTap: onSeeAllTap,
            child: const PassengerEmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'No saved destinations',
              description: 'Tap to add pickup and drop-off places.',
            ),
          )
        else
          PassengerQuickDestinationList(
            destinations: destinations,
            onDestinationTap: onDestinationTap,
          ),
      ],
    );
  }
}

class PassengerQuickDestinationList extends StatelessWidget {
  final List<PassengerQuickDestination> destinations;
  final ValueChanged<PassengerQuickDestination> onDestinationTap;

  const PassengerQuickDestinationList({
    super.key,
    required this.destinations,
    required this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const PassengerEmptyState(
        icon: Icons.bookmark_add_outlined,
        title: 'No saved destinations',
        description: 'Add a place to use it as a quick destination.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: destinations
            .asMap()
            .entries
            .map(
              (MapEntry<int, PassengerQuickDestination> entry) => Padding(
                padding: EdgeInsets.only(
                  right: entry.key == destinations.length - 1 ? 0 : 10,
                ),
                child: SizedBox(
                  width: _quickDestinationCardWidth(context),
                  child: PassengerQuickDestinationCard(
                    destination: entry.value,
                    onTap: () => onDestinationTap(entry.value),
                  ),
                ),
              ),
            )
            .toList(),
      ),
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
    final compact = PassengerUi.isCompactWidth(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: compact ? 94 : 104,
        decoration: BoxDecoration(
          color: PassengerUi.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PassengerUi.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: compact ? 34 : 38,
              height: compact ? 34 : 38,
              decoration: BoxDecoration(
                color: destination.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: destination.hasCustomEmoji
                  ? Center(
                      child: Text(
                        destination.customEmoji!,
                        style: TextStyle(fontSize: compact ? 20 : 22),
                      ),
                    )
                  : Icon(
                      destination.icon,
                      color: destination.accentColor,
                      size: compact ? 19 : 20,
                    ),
            ),
            SizedBox(height: 8),
            Text(
              destination.label,
              style: PassengerUi.cardTitle.copyWith(
                fontSize: compact ? 12.5 : 13.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                destination.address?.trim().isNotEmpty == true
                    ? destination.address!
                    : 'Set location',
                style: PassengerUi.bodyText.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _quickDestinationCardWidth(BuildContext context) {
  return PassengerUi.isCompactWidth(context) ? 128 : 142;
}
