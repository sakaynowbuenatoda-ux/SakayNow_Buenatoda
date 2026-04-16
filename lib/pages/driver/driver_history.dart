import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'driver_data.dart';

class DriverHistoryPage extends StatelessWidget {
  const DriverHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Driver History', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Track completed rides, fare earnings, and recent passenger ratings.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          ...DriverMockData.history.asMap().entries.map(
            (MapEntry<int, DriverTripSummary> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == DriverMockData.history.length - 1 ? 0 : 12,
              ),
              child: DriverHistoryCard(trip: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverHistoryCard extends StatelessWidget {
  final DriverTripSummary trip;

  const DriverHistoryCard({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(trip.passengerName, style: PassengerUi.cardTitle),
              ),
              const PassengerStatusChip(
                label: 'Completed',
                textColor: Color(0xFF166534),
                backgroundColor: Color(0xFFDCFCE7),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(trip.route, style: PassengerUi.bodyText),
          const SizedBox(height: 6),
          Text(trip.completedAt, style: PassengerUi.bodyText.copyWith(fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(trip.earnings, style: PassengerUi.valueText),
              const Spacer(),
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF4B400)),
              const SizedBox(width: 4),
              Text(trip.rating.toStringAsFixed(1), style: PassengerUi.valueText.copyWith(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
