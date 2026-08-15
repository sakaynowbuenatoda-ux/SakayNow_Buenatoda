import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

class ChatQuickReplyBar extends StatelessWidget {
  final List<String> messages;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const ChatQuickReplyBar({
    super.key,
    required this.messages,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        key: const ValueKey<String>('chat_quick_replies'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final message = messages[index];
          return ActionChip(
            key: ValueKey<String>('chat_quick_reply_$message'),
            label: Text(message),
            onPressed: enabled ? () => onSelected(message) : null,
            backgroundColor: PassengerUi.blueSoft,
            disabledColor: PassengerUi.mutedSurface,
            side: BorderSide(color: PassengerUi.border),
            labelStyle: PassengerUi.bodyText.copyWith(
              color: enabled ? PassengerUi.accentBlue : PassengerUi.body,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
