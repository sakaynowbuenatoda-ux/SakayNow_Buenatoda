import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/messages/chat_page.dart';
import 'package:sakaynow_buenatoda/services/chat_service.dart';

void main() {
  testWidgets('shows tombstones and confirms unsend actions', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    const conversationId = 'support_passenger-1';
    final conversation = firestore
        .collection('conversations')
        .doc(conversationId);
    await conversation.set(<String, dynamic>{
      'conversation_id': conversationId,
      'type': 'support',
      'support_user_id': 'passenger-1',
      'participant_ids': <String>['passenger-1'],
      'participant_names': <String, String>{'passenger-1': 'Passenger One'},
      'participant_roles': <String, String>{'passenger-1': 'passenger'},
      'last_message_text': 'Please help',
      'last_message_id': 'message-2',
      'last_message_type': 'text',
      'last_message_sender_id': 'passenger-1',
      'last_message_at': Timestamp.fromDate(DateTime.utc(2026, 8, 16, 10, 1)),
    });
    await conversation.collection('messages').doc('message-1').set(
      <String, dynamic>{
        'message_id': 'message-1',
        'conversation_id': conversationId,
        'sender_id': 'passenger-1',
        'sender_role': 'passenger',
        'type': 'unsent',
        'unsent_by': 'passenger-1',
        'unsent_at': Timestamp.fromDate(DateTime.utc(2026, 8, 16, 10)),
        'created_at': Timestamp.fromDate(DateTime.utc(2026, 8, 16, 9, 59)),
        'read_by': <String, bool>{'passenger-1': true},
      },
    );
    await conversation.collection('messages').doc('message-2').set(
      <String, dynamic>{
        'message_id': 'message-2',
        'conversation_id': conversationId,
        'sender_id': 'passenger-1',
        'sender_role': 'passenger',
        'type': 'text',
        'text': 'Please help',
        'created_at': Timestamp.fromDate(DateTime.utc(2026, 8, 16, 10, 1)),
        'read_by': <String, bool>{'passenger-1': true},
      },
    );

    final actions = <String>[];
    final service = ChatService(
      firestore: firestore,
      chatMessageUnsender: (conversationId, messageId) async {
        actions.add('unsend:$conversationId:$messageId');
      },
      conversationDeleter: (conversationId) async {
        actions.add('delete:$conversationId');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          conversationId: conversationId,
          currentUserId: 'passenger-1',
          currentUserRole: 'passenger',
          title: 'SakayNow Support',
          subtitle: 'Admin',
          chatService: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('You unsent a message'), findsOneWidget);
    expect(find.byTooltip('Message actions'), findsOneWidget);
    expect(find.byTooltip('Conversation actions'), findsOneWidget);

    await tester.longPress(find.text('Please help'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Unsend message?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Unsend'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(actions, contains('unsend:$conversationId:message-2'));
  });
}
