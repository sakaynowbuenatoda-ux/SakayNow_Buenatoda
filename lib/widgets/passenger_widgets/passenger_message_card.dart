import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerMessageCard extends StatelessWidget {
  final PassengerInboxMessage message;

  const PassengerMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: message.isUnread
                  ? PassengerUi.blueSoft
                  : PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              message.senderName.substring(0, 1).toUpperCase(),
              style: PassengerUi.cardTitle,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        message.senderName,
                        style: PassengerUi.cardTitle,
                      ),
                    ),
                    Text(
                      message.timeLabel,
                      style: PassengerUi.bodyText.copyWith(fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                PassengerStatusChip(
                  label: message.tag,
                  textColor: PassengerUi.accentBlue,
                  backgroundColor: PassengerUi.blueSoft,
                ),
                SizedBox(height: 10),
                Text(message.preview, style: PassengerUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
