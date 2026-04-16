import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'driver_data.dart';

class DriverDashboardPage extends StatelessWidget {
  const DriverDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Driver Dashboard', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Monitor performance, earnings, ride completion, and service quality.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          ...DriverMockData.stats.asMap().entries.map(
            (MapEntry<int, DriverInfoStat> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == DriverMockData.stats.length - 1 ? 0 : 12,
              ),
              child: PassengerStatTile(
                icon: entry.value.icon,
                label: entry.value.label,
                value: entry.value.value,
              ),
            ),
          ),
          const SizedBox(height: 20),
          PassengerSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Driver Standing', style: PassengerUi.cardTitle),
                const SizedBox(height: 8),
                Text(
                  'Your profile is positioned for ranking, verification review, and continued ride access once operational data is connected.',
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
