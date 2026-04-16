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
            tag: message.senderName == 'SakayNow Support' ? 'Support' : 'Passenger',
          ),
        )
        .toList();

    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Driver Messages', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Keep passengers updated for smoother pickups and fewer delays.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          ...mappedMessages.asMap().entries.map(
            (MapEntry<int, PassengerInboxMessage> entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key == mappedMessages.length - 1 ? 0 : 12),
              child: PassengerMessageCard(message: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}
