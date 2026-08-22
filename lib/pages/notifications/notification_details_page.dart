import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';

class NotificationDetailsPage extends StatelessWidget {
  final String title;
  final String body;
  final String channel;
  final String? createdAt;

  const NotificationDetailsPage({
    super.key,
    required this.title,
    required this.body,
    required this.channel,
    this.createdAt,
  });

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
        title: Text('Notification update', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: PassengerSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_iconForChannel(channel), color: PassengerUi.icon, size: 32),
              const SizedBox(height: 16),
              Text(
                title.trim().isEmpty ? 'SakayNow update' : title.trim(),
                style: PassengerUi.sectionTitle,
              ),
              const SizedBox(height: 8),
              Text(
                body.trim().isEmpty
                    ? 'Open SakayNow to review this update.'
                    : body.trim(),
                style: PassengerUi.bodyText,
              ),
              const SizedBox(height: 14),
              TimeAgoText(
                dateTimeText: createdAt,
                style: PassengerUi.bodyText.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForChannel(String value) => switch (value.toLowerCase()) {
    'account' => Icons.verified_user_outlined,
    'booking' => Icons.local_taxi_outlined,
    'message' => Icons.chat_bubble_outline_rounded,
    'review' => Icons.star_outline_rounded,
    _ => Icons.notifications_none_rounded,
  };
}
