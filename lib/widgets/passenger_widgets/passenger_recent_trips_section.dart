import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerRecentTripsSection extends StatelessWidget {
  final List<PassengerTripSummary> trips;
  final VoidCallback onViewAllTap;
  final ValueChanged<PassengerTripSummary> onTripTap;

  const PassengerRecentTripsSection({
    super.key,
    required this.trips,
    required this.onViewAllTap,
    required this.onTripTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PassengerSectionHeader(
          title: 'Recent Trips',
          actionLabel: 'View all',
          onActionTap: onViewAllTap,
        ),
        const SizedBox(height: 14),
        ...trips.asMap().entries.map(
          (MapEntry<int, PassengerTripSummary> entry) => Padding(
            padding: EdgeInsets.only(bottom: entry.key == trips.length - 1 ? 0 : 12),
            child: PassengerTripCard(
              trip: entry.value,
              onTap: () => onTripTap(entry.value),
            ),
          ),
        ),
      ],
    );
  }
}

class PassengerTripCard extends StatelessWidget {
  final PassengerTripSummary trip;
  final VoidCallback onTap;

  const PassengerTripCard({
    super.key,
    required this.trip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: PassengerSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: PassengerUi.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: PassengerUi.cardTitle.copyWith(fontSize: 17),
                  ),
                ),
                PassengerStatusChip(
                  label: _formatStatus(trip.status),
                  textColor: const Color(0xFF166534),
                  backgroundColor: const Color(0xFFDCFCE7),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              trip.schedule,
              style: PassengerUi.bodyText.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: PassengerUi.border),
                  ),
                  child: Text(
                    trip.fare,
                    style: PassengerUi.valueText.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.star, size: 16, color: Color(0xFFF4B400)),
                const SizedBox(width: 4),
                Text(
                  trip.rating.toStringAsFixed(1),
                  style: PassengerUi.valueText.copyWith(fontSize: 13),
                ),
                const Spacer(),
                Text(
                  trip.driverName,
                  style: PassengerUi.bodyText.copyWith(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String value) {
    if (value.isEmpty) {
      return 'Unknown';
    }

    return value[0].toUpperCase() + value.substring(1);
  }
}
