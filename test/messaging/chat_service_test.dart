import 'package:cloud_firestore/cloud_firestore.dart';
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
      service = ChatService(
        firestore: firestore,
        rideConversationCreator: (bookingId) async {
          const conversationId = 'ride_pair_passenger-1_driver-1';
          final reference = firestore
              .collection('conversations')
              .doc(conversationId);
          final existing = (await reference.get()).data();
          final existingBookingIds = existing?['booking_ids'];
          final bookingIds = existingBookingIds is Iterable
              ? existingBookingIds.map((value) => value.toString()).toList()
              : <String>[];
          if (!bookingIds.contains(bookingId)) {
            bookingIds.add(bookingId);
          }
          await reference.set(<String, dynamic>{
            'conversation_id': conversationId,
            'type': ConversationType.ride.firestoreValue,
            'booking_id': bookingId,
            'booking_ids': bookingIds,
            'passenger_id': 'passenger-1',
            'driver_id': 'driver-1',
            'participant_ids': <String>['passenger-1', 'driver-1'],
            'participant_names': <String, String>{
              'passenger-1': 'Ana Passenger',
              'driver-1': 'Juan Driver',
            },
            'participant_roles': <String, String>{
              'passenger-1': 'passenger',
              'driver-1': 'driver',
            },
          }, SetOptions(merge: true));
          return conversationId;
        },
        adminDirectConversationCreator: (targetAdminId) async {
          const currentAdminId = 'admin-1';
          final participantIds = <String>[currentAdminId, targetAdminId]
            ..sort();
          final conversationId =
              'admin_direct_${participantIds[0]}_${participantIds[1]}';
          await firestore.collection('conversations').doc(conversationId).set({
            'conversation_id': conversationId,
            'type': ConversationType.adminDirect.firestoreValue,
            'participant_ids': participantIds,
            'participant_names': <String, String>{
              currentAdminId: 'Admin One',
              targetAdminId: 'Admin Two',
            },
            'participant_roles': <String, String>{
              currentAdminId: 'admin',
              targetAdminId: 'super_admin',
            },
          });
          return conversationId;
        },
      );
    });

    test('routes ride conversations through the secured creator', () async {
      final conversationId = await service.createRideConversationFromBooking(
        'booking-1',
      );

      final snapshot = await firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      final conversation = ChatConversation.fromDocument(snapshot);

      expect(conversationId, 'ride_pair_passenger-1_driver-1');
      expect(conversation.type, ConversationType.ride);
      expect(conversation.bookingId, 'booking-1');
      expect(conversation.bookingIds, <String>['booking-1']);
      expect(
        conversation.participantIds,
        containsAll(<String>['passenger-1', 'driver-1']),
      );
      expect(conversation.participantNames['passenger-1'], 'Ana Passenger');
      expect(conversation.participantRoles['driver-1'], 'driver');
    });

    test('treats a legacy booking ID as conversation history', () async {
      final reference = firestore.collection('conversations').doc('legacy');
      await reference.set(<String, dynamic>{
        'conversation_id': 'legacy',
        'type': 'ride',
        'booking_id': 'legacy-booking',
        'participant_ids': <String>['passenger-1', 'driver-1'],
      });

      final conversation = ChatConversation.fromDocument(await reference.get());

      expect(conversation.bookingId, 'legacy-booking');
      expect(conversation.bookingIds, <String>['legacy-booking']);
    });

    test('rejects an empty ride booking before calling the backend', () async {
      await expectLater(
        service.createRideConversationFromBooking('  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'reuses the creator conversation and preserves its messages',
      () async {
        final firstId = await service.createRideConversationFromBooking(
          'booking-1',
        );
        await service.sendMessage(
          conversationId: firstId,
          senderId: 'passenger-1',
          senderRole: 'passenger',
          text: 'Previous ride message',
        );

        final secondId = await service.createRideConversationFromBooking(
          'booking-2',
        );
        final conversation = ChatConversation.fromDocument(
          await firestore.collection('conversations').doc(secondId).get(),
        );
        final messages = await firestore
            .collection('conversations')
            .doc(secondId)
            .collection('messages')
            .get();

        expect(secondId, firstId);
        expect(conversation.bookingId, 'booking-2');
        expect(conversation.bookingIds, <String>['booking-1', 'booking-2']);
        expect(messages.docs.single.data()['text'], 'Previous ride message');
      },
    );

    test(
      'lists only ride and support conversations for user inboxes',
      () async {
        final rideConversationId = await service
            .createRideConversationFromBooking('booking-1');
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
      final conversationId = await service.createRideConversationFromBooking(
        'booking-1',
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
      final conversationId = await service.createRideConversationFromBooking(
        'booking-1',
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
      final rideConversationId = await service
          .createRideConversationFromBooking('booking-1');
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
        targetAdminId: 'admin-2',
      );

      final snapshot = await firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      final conversation = ChatConversation.fromDocument(snapshot);

      expect(conversationId, 'admin_direct_admin-1_admin-2');
      expect(conversation.type, ConversationType.adminDirect);
      expect(conversation.isAdminDirect, isTrue);
      expect(conversation.participantIds, <String>['admin-1', 'admin-2']);
      expect(conversation.participantNames['admin-2'], 'Admin Two');
      expect(conversation.participantRoles['admin-2'], 'super_admin');
      expect(
        conversation.tagFor(currentUserId: 'admin-1', currentUserRole: 'admin'),
        'Super Admin',
      );
    });

    test('sends admin direct messages to the other admin', () async {
      final conversationId = await service.ensureAdminConversation(
        targetAdminId: 'admin-2',
      );

      await service.sendMessage(
        conversationId: conversationId,
        senderId: 'admin-1',
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
        'admin-1': 0,
        'admin-2': 1,
      });
    });

    test('combines support and participant admin-direct inboxes', () async {
      final supportId = await service.ensureSupportConversation(
        userId: 'passenger-1',
        userName: 'Ana Passenger',
        userRole: 'passenger',
      );
      final directId = await service.ensureAdminConversation(
        targetAdminId: 'admin-2',
      );

      final inbox = await service
          .watchAdminInbox('admin-1')
          .firstWhere((conversations) => conversations.length == 2);

      expect(
        inbox.map((conversation) => conversation.conversationId),
        containsAll(<String>[supportId, directId]),
      );
    });
  });
}
