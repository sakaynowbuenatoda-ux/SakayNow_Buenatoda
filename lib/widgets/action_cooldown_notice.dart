import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

class ActionCooldownNotice extends StatelessWidget {
  final String message;
  final IconData icon;

  const ActionCooldownNotice({
    super.key,
    required this.message,
    this.icon = Icons.timer_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PassengerUi.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: PassengerUi.highlightAmber, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: PassengerUi.bodyText.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
