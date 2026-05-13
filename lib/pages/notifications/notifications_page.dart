import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

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
        title: Text('Notifications', style: PassengerUi.cardTitle),
      ),
      body: Center(
        child: Text(
          'Coming soon',
          style: PassengerUi.sectionTitle.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
