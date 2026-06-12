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
  });
}
