import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String role;
  final String type;
  final String title;
  final String body;
  final String channel;
  final String sourceId;
  final Map<String, String> data;
  final bool isRead;
  final bool pushSent;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.role,
    required this.type,
    required this.title,
    required this.body,
    required this.channel,
    required this.sourceId,
    required this.data,
    required this.isRead,
    required this.pushSent,
    required this.createdAt,
    required this.readAt,
  });

  factory AppNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AppNotification(
      id: (data['notification_id'] ?? document.id).toString(),
      userId: (data['user_id'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      title: (data['title'] ?? 'SakayNow').toString(),
      body: (data['body'] ?? 'You have a new update.').toString(),
      channel: (data['channel'] ?? 'system').toString(),
      sourceId: (data['source_id'] ?? '').toString(),
      data: _readStringMap(data['data']),
      isRead: data['is_read'] == true,
      pushSent: data['push_sent'] == true,
      createdAt: _readDate(data['created_at']),
      readAt: _readDate(data['read_at']),
    );
  }

  String? get bookingId => _readNullable(data['booking_id']);
  String? get conversationId => _readNullable(data['conversation_id']);
  String? get reviewId => _readNullable(data['review_id']);

  Map<String, String> get routingData => <String, String>{
    ...data,
    'notification_id': id,
    'type': type,
    'channel': channel,
    'title': title,
    'body': body,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  static Map<String, String> _readStringMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }

    return value.map(
      (key, entry) => MapEntry(key.toString(), entry?.toString() ?? ''),
    );
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

  static String? _readNullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') {
      return null;
    }

    return text;
  }
}
