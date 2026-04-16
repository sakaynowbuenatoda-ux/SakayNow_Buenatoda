import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerHistory extends StatelessWidget {
  final String userId;
  final String firstName;
  final String role;

  const PassengerHistory({
    super.key,
    required this.userId,
    required this.firstName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Trip History', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Review completed rides, verified fares, and driver ratings for accountability.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          PassengerRecentTripsSection(
            trips: PassengerMockData.recentTrips,
            onViewAllTap: () => _showSnackBar(
              context,
              'Showing the latest completed rides.',
            ),
            onTripTap: (PassengerTripSummary trip) =>
                _showSnackBar(context, 'Opened ${trip.destination}.'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
