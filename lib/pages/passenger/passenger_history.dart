import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class PassengerHistory extends StatelessWidget {
  final String userId;
  final String firstName;
  final String passengerType;

  const PassengerHistory({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'History',
            subtitle: 'Review completed rides, routes, fares, and ratings.',
            icon: Icons.receipt_long_rounded,
            accentColor: PassengerUi.secondary,
          ),
          SizedBox(height: 16),
          PassengerRecentTripsSection(
            passengerId: userId,
            title: 'Trips',
            actionLabel: '',
          ),
        ],
      ),
    );
  }
}
