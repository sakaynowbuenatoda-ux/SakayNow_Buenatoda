import 'package:flutter/material.dart';

import '../../widgets/driver_rating_leaderboard_panel.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class DriverLeaderboardPage extends StatelessWidget {
  final String? highlightDriverId;

  const DriverLeaderboardPage({super.key, this.highlightDriverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        title: Text('Leaderboard', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerPageHeader(
              title: 'Driver Leaderboard',
              subtitle: 'Top drivers ranked by completed trip reviews.',
              icon: Icons.emoji_events_rounded,
              accentColor: PassengerUi.highlightAmber,
            ),
            const SizedBox(height: 16),
            DriverRatingLeaderboardPanel(
              limit: 20,
              title: 'Top 20 Drivers',
              highlightDriverId: highlightDriverId,
              showWeightedScore: true,
            ),
          ],
        ),
      ),
    );
  }
}
