import 'package:flutter/material.dart';

import '../../widgets/time_ago_text.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'driver_data.dart';
import 'driver_home.dart';

class DriverHistoryPage extends StatelessWidget {
  final String driverId;

  const DriverHistoryPage({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'History',
            subtitle: 'See finished trips, ratings, and earnings at a glance.',
            icon: Icons.history_rounded,
            accentColor: PassengerUi.secondary,
          ),
          SizedBox(height: 16),
          DriverRecentTripsSection(driverId: driverId),
          SizedBox(height: 20),
          PassengerSectionHeader(title: 'Sample Records'),
          SizedBox(height: 12),
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

  const DriverHistoryCard({super.key, required this.trip});

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
              PassengerStatusChip(
                label: 'Completed',
                textColor: PassengerUi.successText,
                backgroundColor: PassengerUi.successBackground,
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(trip.route, style: PassengerUi.bodyText),
          SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: PassengerUi.accentBlue,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.completedAt,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              TimeAgoText(
                dateTime: trip.completedDate,
                style: PassengerUi.valueText.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(trip.earnings, style: PassengerUi.valueText),
              Spacer(),
              Icon(
                Icons.star_rounded,
                size: 16,
                color: PassengerUi.highlightAmber,
              ),
              SizedBox(width: 4),
              Text(
                trip.rating.toStringAsFixed(1),
                style: PassengerUi.valueText.copyWith(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
