import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerPaymentMethodCard extends StatelessWidget {
  final PassengerSavedPaymentMethod method;

  const PassengerPaymentMethodCard({
    super.key,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: method.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(method.icon, color: method.accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(method.label, style: PassengerUi.cardTitle),
                const SizedBox(height: 4),
                Text(
                  _maskedAccount,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }

  String get _maskedAccount => '${method.accountName} ending in ${method.lastDigits}';
}
