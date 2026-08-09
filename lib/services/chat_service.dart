import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../core/session/user_roles.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_participant_profile.dart';

typedef AdminDirectConversationCreator =
    Future<String> Function(String targetAdminId);

class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AdminDirectConversationCreator? adminDirectConversationCreator,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions,
       _adminDirectConversationCreator = adminDirectConversationCreator;

  static const int maxMessageLength = 1000;
  static final List<String> _userVisibleConversationTypes = <String>[
    ConversationType.ride.firestoreValue,
    ConversationType.support.firestoreValue,
  ];

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final AdminDirectConversationCreator? _adminDirectConversationCreator;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<ChatConversation>> watchUserConversations(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<List<ChatConversation>>.value(<ChatConversation>[]);
    }

    return _userConversationsQuery(normalizedUserId).snapshots().map((
      snapshot,
    ) {
      final conversations = snapshot.docs
          .map(ChatConversation.fromDocument)
          .toList();
      conversations.sort(_compareConversationsByActivity);
      return conversations;
    });
  }

  Stream<List<ChatConversation>> watchAdminSupportConversations() {
    return _conversations
        .where('type', isEqualTo: ConversationType.support.firestoreValue)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(ChatConversation.fromDocument)
              .toList();
          conversations.sort(_compareConversationsByActivity);
          return conversations;
        });
  }

  Stream<int> watchAdminSupportUnreadCount() {
    return watchAdminSupportConversations().map((conversations) {
      return conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.adminUnreadCount,
      );
    });
  }

  Stream<List<ChatConversation>> watchAdminDirectConversations(String adminId) {
    final normalizedAdminId = adminId.trim();
    if (normalizedAdminId.isEmpty) {
      return Stream<List<ChatConversation>>.value(<ChatConversation>[]);
    }

    return _conversations
        .where('participant_ids', arrayContains: normalizedAdminId)
        .where('type', isEqualTo: ConversationType.adminDirect.firestoreValue)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(ChatConversation.fromDocument)
              .toList();
          conversations.sort(_compareConversationsByActivity);
          return conversations;
        });
  }

  Stream<List<ChatConversation>> watchAdminInbox(String adminId) async* {
    var support = <ChatConversation>[];
    var direct = <ChatConversation>[];
    final updates = StreamController<void>();
    final supportSubscription = watchAdminSupportConversations().listen((
      value,
    ) {
      support = value;
      updates.add(null);
    }, onError: updates.addError);
    final directSubscription = watchAdminDirectConversations(adminId).listen((
      value,
    ) {
      direct = value;
      updates.add(null);
    }, onError: updates.addError);

    try {
      await for (final _ in updates.stream) {
        final conversations = <ChatConversation>[...support, ...direct];
        conversations.sort(_compareConversationsByActivity);
        yield conversations;
      }
    } finally {
      await supportSubscription.cancel();
      await directSubscription.cancel();
      await updates.close();
    }
  }

  Stream<int> watchAdminInboxUnreadCount({
    required String adminId,
    required String adminRole,
  }) {
    return watchAdminInbox(adminId).map((conversations) {
      return conversations.fold<int>(
        0,
        (total, conversation) =>
            total +
            conversation.unreadCountFor(
              currentUserId: adminId,
              currentUserRole: adminRole,
            ),
      );
    });
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('created_at')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(ChatMessage.fromDocument).toList();
        });
  }

  Stream<ChatConversation?> watchConversation(String conversationId) {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) {
      return Stream<ChatConversation?>.value(null);
    }

    return _conversations.doc(normalizedConversationId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        return null;
      }

      return ChatConversation.fromDocument(snapshot);
    });
  }

  Future<ChatParticipantProfile?> loadParticipantProfile(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }

    final snapshot = await _users.doc(normalizedUserId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    return ChatParticipantProfile.fromUserData(
      userId: normalizedUserId,
      data: data,
    );
  }

  Future<String> ensureSupportConversation({
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedName = _normalizeName(userName, fallback: 'SakayNow User');
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('A signed-in user is required.');
    }

    final conversationId = 'support_$normalizedUserId';
    final conversationRef = _conversations.doc(conversationId);

    await conversationRef.set(<String, dynamic>{
      'conversation_id': conversationId,
      'type': ConversationType.support.firestoreValue,
      'support_user_id': normalizedUserId,
      'admin_visible': true,
      'participant_ids': <String>[normalizedUserId],
      'participant_names': <String, String>{normalizedUserId: normalizedName},
      'participant_roles': <String, String>{
        normalizedUserId: _normalizeRole(userRole),
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return conversationId;
  }

  Future<String> ensureAdminConversation({
    required String targetAdminId,
  }) async {
    final normalizedTargetAdminId = targetAdminId.trim();
    if (normalizedTargetAdminId.isEmpty) {
      throw ArgumentError('Choose an admin to message.');
    }

    final creator = _adminDirectConversationCreator;
    if (creator != null) {
      return creator(normalizedTargetAdminId);
    }

    final functions =
        _functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    final callable = functions.httpsCallable('ensureAdminDirectConversation');
    final result = await callable.call<Map<String, dynamic>>({
      'target_admin_id': normalizedTargetAdminId,
    });
    final conversationId =
        result.data['conversation_id']?.toString().trim() ?? '';
    if (conversationId.isEmpty) {
      throw StateError('Admin conversation was created without an ID.');
    }
    return conversationId;
  }

  Future<String> createRideConversationFromBooking(String bookingId) async {
    final bookingSnapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
    final passengerId = _readRequiredId(
      bookingData['passenger_id'],
      'Passenger',
    );
    final driverId = _readRequiredId(bookingData['driver_id'], 'Driver');

    final passenger = await _loadUserSummary(passengerId);
    final driver = await _loadUserSummary(driverId);

    return ensureRideConversation(
      bookingId: bookingId,
      passengerId: passengerId,
      passengerName: passenger.displayName,
      driverId: driverId,
      driverName: driver.displayName,
    );
  }

  Future<String> ensureRideConversation({
    required String bookingId,
    required String passengerId,
    required String passengerName,
    required String driverId,
    required String driverName,
  }) async {
    final normalizedBookingId = bookingId.trim();
    final normalizedPassengerId = passengerId.trim();
    final normalizedDriverId = driverId.trim();
    if (normalizedBookingId.isEmpty ||
        normalizedPassengerId.isEmpty ||
        normalizedDriverId.isEmpty) {
      throw ArgumentError('Ride conversations require a booking and users.');
    }

    final conversationId = 'ride_$normalizedBookingId';
    final conversationRef = _conversations.doc(conversationId);

    await conversationRef.set(<String, dynamic>{
      'conversation_id': conversationId,
      'type': ConversationType.ride.firestoreValue,
      'booking_id': normalizedBookingId,
      'passenger_id': normalizedPassengerId,
      'driver_id': normalizedDriverId,
      'participant_ids': <String>[normalizedPassengerId, normalizedDriverId],
      'participant_names': <String, String>{
        normalizedPassengerId: _normalizeName(
          passengerName,
          fallback: 'Passenger',
        ),
        normalizedDriverId: _normalizeName(driverName, fallback: 'Driver'),
      },
      'participant_roles': <String, String>{
        normalizedPassengerId: 'passenger',
        normalizedDriverId: 'driver',
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return conversationId;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String text,
    String? clientMessageId,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    if (normalizedText.length > maxMessageLength) {
      throw ArgumentError('Message is too long.');
    }

    final normalizedClientMessageId = clientMessageId?.trim() ?? '';
    final conversationRef = _conversations.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversationRef);
      if (!snapshot.exists) {
        throw StateError('Conversation was not found.');
      }

      final conversation = ChatConversation.fromDocument(snapshot);
      final normalizedSenderRole = _normalizeRole(senderRole);
      final isAdminSupportMessage =
          conversation.isSupport && isAdminStaffRole(normalizedSenderRole);
      if (!conversation.participantIds.contains(senderId) &&
          !isAdminSupportMessage) {
        throw StateError('You are not part of this conversation.');
      }

      final messageData = <String, dynamic>{
        'message_id': messageRef.id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_role': normalizedSenderRole,
        'text': normalizedText,
        'type': 'text',
        'read_by': <String, bool>{senderId: true},
        'created_at': FieldValue.serverTimestamp(),
      };
      if (normalizedClientMessageId.isNotEmpty) {
        messageData['client_message_id'] = normalizedClientMessageId;
      }

      transaction.set(messageRef, messageData);

      final updates = <String, dynamic>{
        'last_message_text': normalizedText,
        'last_message_sender_id': senderId,
        'last_message_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (conversation.participantIds.contains(senderId)) {
        updates['unread_counts.$senderId'] = 0;
      }

      for (final participantId in conversation.participantIds) {
        if (participantId == senderId) {
          continue;
        }

        updates['unread_counts.$participantId'] = FieldValue.increment(1);
      }

      if (conversation.isSupport) {
        updates['admin_unread_count'] = isAdminStaffRole(normalizedSenderRole)
            ? 0
            : FieldValue.increment(1);
      }

      transaction.update(conversationRef, updates);
    });
  }

  Future<void> markConversationRead({
    required String conversationId,
    required String userId,
    required String userRole,
  }) async {
    final conversationRef = _conversations.doc(conversationId);
    final snapshot = await conversationRef.get();
    if (!snapshot.exists) {
      return;
    }

    final conversation = ChatConversation.fromDocument(snapshot);
    final updates = <String, dynamic>{
      'last_read_at.$userId': FieldValue.serverTimestamp(),
    };

    if (conversation.participantIds.contains(userId)) {
      updates['unread_counts.$userId'] = 0;
    }

    if (conversation.isSupport && isAdminStaffRole(_normalizeRole(userRole))) {
      updates['admin_unread_count'] = 0;
    }

    await conversationRef.update(updates);
  }

  Future<void> markUserConversationsRead({
    required String userId,
    required String userRole,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedUserRole = _normalizeRole(userRole);
    if (normalizedUserId.isEmpty) {
      return;
    }

    final snapshot = await _userConversationsQuery(normalizedUserId).get();
    final batch = _firestore.batch();
    var hasUpdates = false;

    for (final document in snapshot.docs) {
      final conversation = ChatConversation.fromDocument(document);
      final unreadCount = conversation.unreadCountFor(
        currentUserId: normalizedUserId,
        currentUserRole: normalizedUserRole,
      );
      if (unreadCount <= 0) {
        continue;
      }

      batch.update(document.reference, <String, dynamic>{
        'last_read_at.$normalizedUserId': FieldValue.serverTimestamp(),
        'unread_counts.$normalizedUserId': 0,
      });
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<_ChatUserSummary> _loadUserSummary(String userId) async {
    final profile = await loadParticipantProfile(userId);

    return _ChatUserSummary(
      displayName: profile?.displayName ?? 'SakayNow User',
      role: profile?.role ?? 'passenger',
    );
  }

  static String _readRequiredId(Object? value, String label) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') {
      throw StateError('$label is missing for this ride.');
    }

    return text;
  }

  static String _normalizeName(String value, {required String fallback}) {
    final text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  static String _normalizeRole(String value) {
    final role = normalizeUserRole(value);
    return switch (role) {
      'driver' => 'driver',
      'admin' => 'admin',
      'super_admin' => 'super_admin',
      _ => 'passenger',
    };
  }

  static int _compareConversationsByActivity(
    ChatConversation a,
    ChatConversation b,
  ) {
    final aDate = a.latestActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.latestActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  }

  Query<Map<String, dynamic>> _userConversationsQuery(String userId) {
    return _conversations
        .where('participant_ids', arrayContains: userId)
        .where('type', whereIn: _userVisibleConversationTypes);
  }
}

class _ChatUserSummary {
  final String displayName;
  final String role;

  const _ChatUserSummary({required this.displayName, required this.role});
}
