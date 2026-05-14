import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.help_outline_rounded,
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final resolvedConfirmColor = confirmColor ?? PassengerUi.primary;

      return AlertDialog(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: resolvedConfirmColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: resolvedConfirmColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: PassengerUi.cardTitle)),
          ],
        ),
        content: Text(message, style: PassengerUi.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep', style: TextStyle(color: PassengerUi.body)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: resolvedConfirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
