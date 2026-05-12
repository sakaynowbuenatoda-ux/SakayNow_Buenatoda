import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_message_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerMessages extends StatelessWidget {
  final String userId;
  final String firstName;
  final String passengerType;

  const PassengerMessages({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Messages',
            subtitle:
                'Keep trip updates and driver conversations easy to scan.',
            icon: Icons.chat_bubble_rounded,
            accentColor: PassengerUi.accentBlue,
          ),
          SizedBox(height: 16),
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
                  textColor: PassengerUi.accentBlue,
                  backgroundColor: PassengerUi.blueSoft,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          ...PassengerMockData.inboxMessages.asMap().entries.map(
            (MapEntry<int, PassengerInboxMessage> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == PassengerMockData.inboxMessages.length - 1
                    ? 0
                    : 12,
              ),
              child: PassengerMessageCard(message: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}
