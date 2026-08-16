import 'package:flutter/material.dart';

import '../../controllers/quick_destinations_controller.dart';
import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class PassengerHistory extends StatelessWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final QuickDestinationsController quickDestinationsController;

  const PassengerHistory({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.quickDestinationsController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        title: Text('Trip History', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerRecentTripsSection(
              passengerId: userId,
              title: 'Trips',
              actionLabel: '',
              quickDestinationsController: quickDestinationsController,
            ),
          ],
        ),
      ),
    );
  }
}
