import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String text;
  final String type;
  final String? clientMessageId;
  final Map<String, bool> readBy;
  final DateTime? createdAt;

  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.type,
    this.clientMessageId,
    required this.readBy,
    required this.createdAt,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;
  bool isReadBy(String userId) => readBy[userId] == true;

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ChatMessage(
      messageId: (data['message_id'] ?? document.id).toString(),
      conversationId: (data['conversation_id'] ?? '').toString(),
      senderId: (data['sender_id'] ?? '').toString(),
      senderRole: (data['sender_role'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      clientMessageId: _readNullableString(data['client_message_id']),
      readBy: _readBoolMap(data['read_by']),
      createdAt: _readDate(data['created_at']),
    );
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static Map<String, bool> _readBoolMap(Object? value) {
    if (value is! Map) {
      return <String, bool>{};
    }

    return value.map((key, item) => MapEntry(key.toString(), item == true));
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
}
