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
        backgroundColor: PassengerUi.background,
        foregroundColor: PassengerUi.title,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Leaderboard',
          style: PassengerUi.cardTitle.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: PassengerPageContainer(
        maxContentWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DriverRatingLeaderboardPanel(
              limit: 20,
              title: '',
              highlightDriverId: highlightDriverId,
            ),
          ],
        ),
      ),
    );
  }
}
