import '../core/session/user_roles.dart';
import 'chat_conversation.dart';

enum ChatQuickReplyContext {
  driverRide,
  passengerRide,
  adminSupport,
  userSupport,
  adminDirect,
}

class ChatQuickReplies {
  const ChatQuickReplies._();

  static const Map<ChatQuickReplyContext, List<String>> _messages = {
    ChatQuickReplyContext.driverRide: <String>[
      "I'm on the way.",
      'Please wait a minute.',
      "I've arrived at the pickup point.",
      'Where should I meet you?',
    ],
    ChatQuickReplyContext.passengerRide: <String>[
      'Are you on the way?',
      'Please wait a minute.',
      "I'm at the pickup point.",
      'Where are you now?',
    ],
    ChatQuickReplyContext.adminSupport: <String>[
      'How may I help you?',
      "We're checking your concern.",
      'Please provide more details.',
      'Your concern has been resolved.',
    ],
    ChatQuickReplyContext.userSupport: <String>[
      'I need help with a booking.',
      'I have a payment concern.',
      'I want to report an issue.',
      'I need help with my account.',
    ],
    ChatQuickReplyContext.adminDirect: <String>[
      'Please review this.',
      "I'm checking it now.",
      'This has been resolved.',
    ],
  };

  static List<String> forConversation({
    required ChatConversation? conversation,
    required String currentUserRole,
  }) {
    if (conversation == null) {
      return const <String>[];
    }

    final role = normalizeUserRole(currentUserRole);
    final context = switch (conversation.type) {
      ConversationType.ride =>
        role == 'driver'
            ? ChatQuickReplyContext.driverRide
            : ChatQuickReplyContext.passengerRide,
      ConversationType.support =>
        isAdminStaffRole(role)
            ? ChatQuickReplyContext.adminSupport
            : ChatQuickReplyContext.userSupport,
      ConversationType.adminDirect => ChatQuickReplyContext.adminDirect,
    };
    return _messages[context] ?? const <String>[];
  }
}
