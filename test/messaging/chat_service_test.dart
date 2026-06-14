import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/chat_conversation.dart';
import 'package:sakaynow_buenatoda/services/chat_service.dart';

void main() {
  group('ChatService', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
    });

    test(
      'creates stable ride conversations with passenger and driver participants',
      () async {
        final conversationId = await service.ensureRideConversation(
          bookingId: 'booking-1',
          passengerId: 'passenger-1',
          passengerName: 'Ana Passenger',
          driverId: 'driver-1',
          driverName: 'Juan Driver',
        );

        final snapshot = await firestore
            .collection('conversations')
            .doc(conversationId)
            .get();
        final conversation = ChatConversation.fromDocument(snapshot);

        expect(conversationId, 'ride_booking-1');
        expect(conversation.type, ConversationType.ride);
        expect(conversation.bookingId, 'booking-1');
        expect(
          conversation.participantIds,
          containsAll(<String>['passenger-1', 'driver-1']),
        );
        expect(conversation.participantNames['passenger-1'], 'Ana Passenger');
        expect(conversation.participantRoles['driver-1'], 'driver');
      },
    );

    test(
      'lists only ride and support conversations for user inboxes',
      () async {
        final rideConversationId = await service.ensureRideConversation(
          bookingId: 'booking-1',
          passengerId: 'passenger-1',
          passengerName: 'Ana Passenger',
          driverId: 'driver-1',
          driverName: 'Juan Driver',
        );
        final supportConversationId = await service.ensureSupportConversation(
          userId: 'passenger-1',
          userName: 'Ana Passenger',
          userRole: 'passenger',
        );
        await firestore
            .collection('conversations')
            .doc('admin_direct_passenger-1_admin-1')
            .set(<String, dynamic>{
              'conversation_id': 'admin_direct_passenger-1_admin-1',
              'type': ConversationType.adminDirect.firestoreValue,
              'participant_ids': <String>['passenger-1', 'admin-1'],
              'participant_names': <String, String>{
                'passenger-1': 'Ana Passenger',
                'admin-1': 'Admin',
              },
              'participant_roles': <String, String>{
                'passenger-1': 'passenger',
                'admin-1': 'admin',
              },
            });

        final conversations = await service
            .watchUserConversations('passenger-1')
            .first;

        expect(
          conversations.map((conversation) => conversation.conversationId),
          containsAll(<String>[rideConversationId, supportConversationId]),
        );
        expect(
          conversations.map((conversation) => conversation.type),
          isNot(contains(ConversationType.adminDirect)),
        );
      },
    );

    test('sends trimmed messages and updates unread counters', () async {
      final conversationId = await service.ensureRideConversation(
        bookingId: 'booking-1',
        passengerId: 'passenger-1',
        passengerName: 'Ana Passenger',
        driverId: 'driver-1',
        driverName: 'Juan Driver',
      );

      await service.sendMessage(
        conversationId: conversationId,
        senderId: 'passenger-1',
        senderRole: 'passenger',
        text: '  Hello driver  ',
        clientMessageId: 'local-message-1',
      );

      final messages = await firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();
      final conversation =
          (await firestore
                  .collection('conversations')
                  .doc(conversationId)
                  .get())
              .data()!;

      expect(messages.docs, hasLength(1));
      expect(messages.docs.single.data()['text'], 'Hello driver');
      expect(
        messages.docs.single.data()['client_message_id'],
        'local-message-1',
      );
      expect(messages.docs.single.data()['read_by.passenger-1'], isNull);
      expect(messages.docs.single.data()['read_by'], <String, bool>{
        'passenger-1': true,
      });
      expect(conversation['last_message_text'], 'Hello driver');
      expect(conversation['last_message_sender_id'], 'passenger-1');
      expect(conversation['unread_counts'], <String, dynamic>{
        'passenger-1': 0,
        'driver-1': 1,
      });
    });

    test('rejects empty, oversized, and non-participant messages', () async {
      final conversationId = await service.ensureRideConversation(
        bookingId: 'booking-1',
        passengerId: 'passenger-1',
        passengerName: 'Ana Passenger',
        driverId: 'driver-1',
        driverName: 'Juan Driver',
      );

      await expectLater(
        service.sendMessage(
          conversationId: conversationId,
          senderId: 'passenger-1',
          senderRole: 'passenger',
          text: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        service.sendMessage(
          conversationId: conversationId,
          senderId: 'passenger-1',
          senderRole: 'passenger',
          text: 'x' * (ChatService.maxMessageLength + 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        service.sendMessage(
          conversationId: conversationId,
          senderId: 'outsider',
          senderRole: 'passenger',
          text: 'Hello',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('marks only ride and support user conversations as read', () async {
      final rideConversationId = await service.ensureRideConversation(
        bookingId: 'booking-1',
        passengerId: 'passenger-1',
        passengerName: 'Ana Passenger',
        driverId: 'driver-1',
        driverName: 'Juan Driver',
      );
      final supportConversationId = await service.ensureSupportConversation(
        userId: 'passenger-1',
        userName: 'Ana Passenger',
        userRole: 'passenger',
      );
      await firestore
          .collection('conversations')
          .doc(rideConversationId)
          .update(<String, dynamic>{
            'unread_counts': <String, dynamic>{'passenger-1': 2},
          });
      await firestore
          .collection('conversations')
          .doc(supportConversationId)
          .update(<String, dynamic>{
            'unread_counts': <String, dynamic>{'passenger-1': 3},
          });
      await firestore
          .collection('conversations')
          .doc('admin_direct_passenger-1_admin-1')
          .set(<String, dynamic>{
            'conversation_id': 'admin_direct_passenger-1_admin-1',
            'type': ConversationType.adminDirect.firestoreValue,
            'participant_ids': <String>['passenger-1', 'admin-1'],
            'participant_names': <String, String>{
              'passenger-1': 'Ana Passenger',
              'admin-1': 'Admin',
            },
            'participant_roles': <String, String>{
              'passenger-1': 'passenger',
              'admin-1': 'admin',
            },
            'unread_counts': <String, dynamic>{'passenger-1': 4},
          });

      await service.markUserConversationsRead(
        userId: 'passenger-1',
        userRole: 'passenger',
      );

      final rideConversation =
          (await firestore
                  .collection('conversations')
                  .doc(rideConversationId)
                  .get())
              .data()!;
      final supportConversation =
          (await firestore
                  .collection('conversations')
                  .doc(supportConversationId)
                  .get())
              .data()!;
      final adminDirectConversation =
          (await firestore
                  .collection('conversations')
                  .doc('admin_direct_passenger-1_admin-1')
                  .get())
              .data()!;

      expect(rideConversation['unread_counts']['passenger-1'], 0);
      expect(supportConversation['unread_counts']['passenger-1'], 0);
      expect(adminDirectConversation['unread_counts']['passenger-1'], 4);
    });

    test('allows admin replies in support conversations', () async {
      final conversationId = await service.ensureSupportConversation(
        userId: 'passenger-1',
        userName: 'Ana Passenger',
        userRole: 'passenger',
      );

      await service.sendMessage(
        conversationId: conversationId,
        senderId: 'admin-1',
        senderRole: 'admin',
        text: 'We are checking this.',
      );

      final conversation =
          (await firestore
                  .collection('conversations')
                  .doc(conversationId)
                  .get())
              .data()!;
      final messages = await firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      expect(messages.docs, hasLength(1));
      expect(messages.docs.single.data()['sender_role'], 'admin');
      expect(conversation['admin_unread_count'], 0);
      expect(conversation['unread_counts'], <String, dynamic>{
        'passenger-1': 1,
      });
    });

    test('creates stable admin direct conversations', () async {
      final conversationId = await service.ensureAdminConversation(
        currentAdminId: 'main-admin',
        currentAdminName: 'admin',
        targetAdminId: 'admin-2',
        targetAdminName: 'Maria Admin',
      );

      final snapshot = await firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      final conversation = ChatConversation.fromDocument(snapshot);

      expect(conversationId, 'admin_direct_main-admin_admin-2');
      expect(conversation.type, ConversationType.adminDirect);
      expect(conversation.isAdminDirect, isTrue);
      expect(conversation.participantIds, <String>['main-admin', 'admin-2']);
      expect(conversation.participantNames['admin-2'], 'Maria Admin');
      expect(conversation.participantRoles['main-admin'], 'admin');
      expect(
        conversation.tagFor(
          currentUserId: 'main-admin',
          currentUserRole: 'admin',
        ),
        'Admin',
      );
    });

    test('sends admin direct messages to the other admin', () async {
      final conversationId = await service.ensureAdminConversation(
        currentAdminId: 'main-admin',
        currentAdminName: 'admin',
        targetAdminId: 'admin-2',
        targetAdminName: 'Maria Admin',
      );

      await service.sendMessage(
        conversationId: conversationId,
        senderId: 'main-admin',
        senderRole: 'admin',
        text: 'Please review the queue.',
      );

      final conversation =
          (await firestore
                  .collection('conversations')
                  .doc(conversationId)
                  .get())
              .data()!;
      final messages = await firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      expect(messages.docs, hasLength(1));
      expect(messages.docs.single.data()['sender_role'], 'admin');
      expect(conversation['last_message_text'], 'Please review the queue.');
      expect(conversation['unread_counts'], <String, dynamic>{
        'main-admin': 0,
        'admin-2': 1,
      });
    });
  });
}
