import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_message_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerMessages extends StatelessWidget {
  final String userId;
  final String firstName;
  final String role;

  const PassengerMessages({
    super.key,
    required this.userId,
    required this.firstName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Messages', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Stay in touch with drivers and support during booking, pickup, and follow-up.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          PassengerSurfaceCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Unread conversations',
                    style: PassengerUi.cardTitle,
                  ),
                ),
                PassengerStatusChip(
                  label: '1 new',
                  textColor: Color(0xFF1D4ED8),
                  backgroundColor: Color(0xFFDBEAFE),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...PassengerMockData.inboxMessages.asMap().entries.map(
            (MapEntry<int, PassengerInboxMessage> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == PassengerMockData.inboxMessages.length - 1 ? 0 : 12,
              ),
              child: PassengerMessageCard(message: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}
