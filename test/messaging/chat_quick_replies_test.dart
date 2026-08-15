import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/chat_conversation.dart';
import 'package:sakaynow_buenatoda/models/chat_quick_replies.dart';
import 'package:sakaynow_buenatoda/widgets/chat_quick_reply_bar.dart';

void main() {
  group('ChatQuickReplies', () {
    test('provides driver and passenger ride replies', () {
      final conversation = _conversation(ConversationType.ride);

      expect(
        ChatQuickReplies.forConversation(
          conversation: conversation,
          currentUserRole: 'driver',
        ),
        <String>[
          "I'm on the way.",
          'Please wait a minute.',
          "I've arrived at the pickup point.",
          'Where should I meet you?',
        ],
      );
      expect(
        ChatQuickReplies.forConversation(
          conversation: conversation,
          currentUserRole: 'student',
        ),
        <String>[
          'Are you on the way?',
          'Please wait a minute.',
          "I'm at the pickup point.",
          'Where are you now?',
        ],
      );
    });

    test('provides admin and user support replies', () {
      final conversation = _conversation(ConversationType.support);

      expect(
        ChatQuickReplies.forConversation(
          conversation: conversation,
          currentUserRole: 'super_admin',
        ),
        <String>[
          'How may I help you?',
          "We're checking your concern.",
          'Please provide more details.',
          'Your concern has been resolved.',
        ],
      );
      expect(
        ChatQuickReplies.forConversation(
          conversation: conversation,
          currentUserRole: 'passenger',
        ),
        <String>[
          'I need help with a booking.',
          'I have a payment concern.',
          'I want to report an issue.',
          'I need help with my account.',
        ],
      );
    });

    test('provides admin-direct replies and none while loading', () {
      expect(
        ChatQuickReplies.forConversation(
          conversation: _conversation(ConversationType.adminDirect),
          currentUserRole: 'admin',
        ),
        <String>[
          'Please review this.',
          "I'm checking it now.",
          'This has been resolved.',
        ],
      );
      expect(
        ChatQuickReplies.forConversation(
          conversation: null,
          currentUserRole: 'admin',
        ),
        isEmpty,
      );
    });
  });

  testWidgets('quick replies send once and disable while sending', (
    tester,
  ) async {
    final selected = <String>[];

    Future<void> pumpBar({required bool enabled}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatQuickReplyBar(
              messages: const <String>['Please wait a minute.'],
              enabled: enabled,
              onSelected: selected.add,
            ),
          ),
        ),
      );
    }

    await pumpBar(enabled: true);
    await tester.tap(find.text('Please wait a minute.'));
    await tester.pump();
    expect(selected, <String>['Please wait a minute.']);

    await pumpBar(enabled: false);
    await tester.tap(find.text('Please wait a minute.'));
    await tester.pump();
    expect(selected, hasLength(1));
  });
}

ChatConversation _conversation(ConversationType type) {
  return ChatConversation(
    conversationId: 'conversation-1',
    type: type,
    bookingId: type == ConversationType.ride ? 'booking-1' : null,
    bookingIds: type == ConversationType.ride
        ? const <String>['booking-1']
        : const <String>[],
    passengerId: type == ConversationType.ride ? 'passenger-1' : null,
    driverId: type == ConversationType.ride ? 'driver-1' : null,
    supportUserId: type == ConversationType.support ? 'passenger-1' : null,
    participantIds: const <String>['passenger-1', 'driver-1'],
    participantNames: const <String, String>{},
    participantRoles: const <String, String>{},
    lastMessageText: '',
    lastMessageSenderId: null,
    lastMessageAt: null,
    unreadCounts: const <String, int>{},
    adminUnreadCount: 0,
    lastReadAt: const <String, DateTime>{},
    createdAt: null,
    updatedAt: null,
  );
}
