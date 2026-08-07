import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
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
            icon: Icons.receipt_long_rounded,
            accentColor: PassengerUi.secondary,
          ),
          SizedBox(height: 16),
          DriverRecentTripsSection(driverId: driverId),
        ],
      ),
    );
  }
}
