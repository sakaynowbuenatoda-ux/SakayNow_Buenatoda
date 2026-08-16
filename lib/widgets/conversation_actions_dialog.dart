import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

enum ConversationAction { delete }

Future<ConversationAction?> showConversationActionsDialog(
  BuildContext context, {
  required String conversationTitle,
}) {
  return showDialog<ConversationAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: PassengerUi.surface,
      surfaceTintColor: PassengerUi.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Conversation options', style: PassengerUi.cardTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              conversationTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText,
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey<String>('conversation_action_delete'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: PassengerUi.dangerSoft,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade700,
              ),
              title: Text(
                'Delete',
                style: PassengerUi.valueText.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
              subtitle: Text(
                'Remove this conversation for you',
                style: PassengerUi.bodyText.copyWith(fontSize: 12),
              ),
              onTap: () =>
                  Navigator.of(dialogContext).pop(ConversationAction.delete),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('Cancel', style: TextStyle(color: PassengerUi.body)),
        ),
      ],
    ),
  );
}
