import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_message_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../passenger/passenger_data.dart';
import 'driver_data.dart';

class DriverMessagesPage extends StatelessWidget {
  const DriverMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<PassengerInboxMessage> mappedMessages = DriverMockData.messages
        .map(
          (DriverMessageSummary message) => PassengerInboxMessage(
            senderName: message.senderName,
            preview: message.preview,
            timeLabel: message.timeLabel,
            isUnread: message.isUnread,
            tag: message.senderName == 'SakayNow Support'
                ? 'Support'
                : 'Passenger',
          ),
        )
        .toList();

    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Messages',
            subtitle:
                'Passenger and support conversations stay organized here.',
            icon: Icons.chat_bubble_rounded,
            accentColor: PassengerUi.accentBlue,
          ),
          SizedBox(height: 16),
          ...mappedMessages.asMap().entries.map(
            (MapEntry<int, PassengerInboxMessage> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == mappedMessages.length - 1 ? 0 : 12,
              ),
              child: PassengerMessageCard(message: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}
