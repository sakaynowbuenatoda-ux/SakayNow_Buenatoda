import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'driver_data.dart';

class DriverDashboardPage extends StatelessWidget {
  final bool isVerified;

  const DriverDashboardPage({super.key, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Dashboard',
            subtitle:
                'Monitor performance, queue readiness, and account standing.',
            icon: Icons.dashboard_rounded,
            accentColor: PassengerUi.primary,
          ),
          SizedBox(height: 16),
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
          SizedBox(height: 20),
          PassengerSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Standing', style: PassengerUi.cardTitle),
                SizedBox(height: 8),
                PassengerStatusChip(
                  label: isVerified
                      ? 'Verified driver'
                      : 'Pending verification',
                  textColor: isVerified
                      ? PassengerUi.successText
                      : PassengerUi.primary,
                  backgroundColor: isVerified
                      ? PassengerUi.successBackground
                      : PassengerUi.dangerSoft,
                ),
                SizedBox(height: 12),
                Text(
                  isVerified
                      ? 'Your verified driver account is ready for profile management, ranking, and continued ride access as operational data is connected.'
                      : 'You can already access your driver home, but profile editing stays locked until an admin verifies your account and reviews your submitted credentials.',
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
