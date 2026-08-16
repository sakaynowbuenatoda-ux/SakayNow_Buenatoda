import 'package:flutter/material.dart';

import '../../widgets/driver_rating_leaderboard_panel.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class DriverLeaderboardPage extends StatelessWidget {
  final String? highlightDriverId;

  const DriverLeaderboardPage({super.key, this.highlightDriverId});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = PassengerUi.isDarkMode;
    final appBarBackground = isDarkMode
        ? const Color(0xFFF3F4F6)
        : Colors.black;
    final appBarForeground = isDarkMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Leaderboard',
          style: PassengerUi.cardTitle.copyWith(
            color: appBarForeground,
            fontWeight: FontWeight.w700,
          ),
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
