import 'package:flutter/material.dart';

import '../../config/app_assets.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class VersionPage extends StatelessWidget {
  const VersionPage({super.key});

  static const String _appName = 'SakayNow Buenatoda';
  static const String _version = '1.0.0';
  static const String _description =
      'A tricycle booking app for Buenavista, Bohol, connecting passengers, drivers, and administrators through verified accounts, transparent fares, live ride tracking, and secure trip history.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('About', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PassengerSurfaceCard(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      AppAssets.logo,
                      width: 82,
                      height: 82,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _appName,
                    textAlign: TextAlign.center,
                    style: PassengerUi.sectionTitle.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description,
                    textAlign: TextAlign.center,
                    style: PassengerUi.bodyText.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  PassengerStatusChip(
                    label: 'Version $_version',
                    textColor: PassengerUi.accentBlue,
                    backgroundColor: PassengerUi.blueSoft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Copyright 2026 SakayNow Buenatoda. All rights reserved.',
              textAlign: TextAlign.center,
              style: PassengerUi.bodyText.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
