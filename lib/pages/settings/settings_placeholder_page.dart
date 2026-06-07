import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class SettingsPlaceholderPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const SettingsPlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text(title, style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: PassengerEmptyState(
          icon: icon,
          title: '$title Coming Soon',
          description: description,
        ),
      ),
    );
  }
}
