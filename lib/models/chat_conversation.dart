import 'package:cloud_firestore/cloud_firestore.dart';

enum ConversationType { ride, support, adminDirect }

extension ConversationTypeFirestore on ConversationType {
  String get firestoreValue {
    return switch (this) {
      ConversationType.ride => 'ride',
      ConversationType.support => 'support',
      ConversationType.adminDirect => 'admin_direct',
    };
  }
}

ConversationType conversationTypeFromString(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'ride' => ConversationType.ride,
    'admin_direct' => ConversationType.adminDirect,
    _ => ConversationType.support,
  };
}

class ChatConversation {
  final String conversationId;
  final ConversationType type;
  final String? bookingId;
  final String? passengerId;
  final String? driverId;
  final String? supportUserId;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles;
  final String lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;
  final int adminUnreadCount;
  final Map<String, DateTime> lastReadAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatConversation({
    required this.conversationId,
    required this.type,
    required this.bookingId,
    required this.passengerId,
    required this.driverId,
    required this.supportUserId,
    required this.participantIds,
    required this.participantNames,
    required this.participantRoles,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.unreadCounts,
    required this.adminUnreadCount,
    required this.lastReadAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSupport => type == ConversationType.support;
  bool get isRide => type == ConversationType.ride;
  bool get isAdminDirect => type == ConversationType.adminDirect;
  bool get hasMessages => lastMessageText.trim().isNotEmpty;

  factory ChatConversation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ChatConversation(
      conversationId: (data['conversation_id'] ?? document.id).toString(),
      type: conversationTypeFromString(data['type']),
      bookingId: _readNullableString(data['booking_id']),
      passengerId: _readNullableString(data['passenger_id']),
      driverId: _readNullableString(data['driver_id']),
      supportUserId: _readNullableString(data['support_user_id']),
      participantIds: _readStringList(data['participant_ids']),
      participantNames: _readStringMap(data['participant_names']),
      participantRoles: _readStringMap(data['participant_roles']),
      lastMessageText: (data['last_message_text'] ?? '').toString(),
      lastMessageSenderId: _readNullableString(data['last_message_sender_id']),
      lastMessageAt: _readDate(data['last_message_at']),
      unreadCounts: _readIntMap(data['unread_counts']),
      adminUnreadCount: _readInt(data['admin_unread_count']),
      lastReadAt: _readDateMap(data['last_read_at']),
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
    );
  }

  String titleFor({
    required String currentUserId,
    required String currentUserRole,
  }) {
    if (isSupport && currentUserRole != 'admin') {
      return 'SakayNow Support';
    }

    final otherId = participantIds
        .where((participantId) => participantId != currentUserId)
        .firstOrNull;
    final otherName = otherId == null ? null : participantNames[otherId];
    if (otherName != null && otherName.trim().isNotEmpty) {
      return otherName.trim();
    }

    if (isSupport) {
      final userId = supportUserId;
      final userName = userId == null ? null : participantNames[userId];
      return userName?.trim().isNotEmpty == true
          ? userName!.trim()
          : 'Support conversation';
    }

    return 'Ride conversation';
  }

  String tagFor({
    required String currentUserId,
    required String currentUserRole,
  }) {
    if (isSupport) {
      return currentUserRole == 'admin' ? 'Support' : 'Admin';
    }

    final otherId = participantIds
        .where((participantId) => participantId != currentUserId)
        .firstOrNull;
    final role = otherId == null ? null : participantRoles[otherId];
    return switch (role) {
      'admin' => 'Admin',
      'driver' => 'Driver',
      'passenger' || 'regular' || 'student' || 'senior_citizen' => 'Passenger',
      _ => 'Ride',
    };
  }

  String previewFor(String currentUserId) {
    if (!hasMessages) {
      if (isSupport) return 'No support messages yet.';
      if (isAdminDirect) return 'No admin messages yet.';
      return 'No ride messages yet.';
    }

    return lastMessageSenderId == currentUserId
        ? 'You: $lastMessageText'
        : lastMessageText;
  }

  int unreadCountFor({
    required String currentUserId,
    required String currentUserRole,
  }) {
    if (currentUserRole == 'admin' && isSupport) {
      return adminUnreadCount;
    }

    return unreadCounts[currentUserId] ?? 0;
  }

  DateTime? get latestActivityAt => lastMessageAt ?? updatedAt ?? createdAt;

  String? otherParticipantId(String currentUserId) {
    return participantIds
        .where((participantId) => participantId != currentUserId)
        .firstOrNull;
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  static Map<String, String> _readStringMap(Object? value) {
    if (value is! Map) {
      return <String, String>{};
    }

    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }

  static Map<String, int> _readIntMap(Object? value) {
    if (value is! Map) {
      return <String, int>{};
    }

    return value.map((key, item) => MapEntry(key.toString(), _readInt(item)));
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static Map<String, DateTime> _readDateMap(Object? value) {
    if (value is! Map) {
      return <String, DateTime>{};
    }

    final dates = <String, DateTime>{};
    for (final entry in value.entries) {
      final date = _readDate(entry.value);
      if (date != null) {
        dates[entry.key.toString()] = date;
      }
    }

    return dates;
  }
}
