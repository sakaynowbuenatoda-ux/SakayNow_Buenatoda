import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String rules;

  setUpAll(() {
    source = File('functions/src/index.ts').readAsStringSync();
    rules = File('firestore.rules').readAsStringSync();
  });

  test('chat mutation callables authenticate and preserve tombstones', () {
    expect(source, contains('export const unsendChatMessage = onCall('));
    expect(
      source,
      contains('export const deleteChatConversationForMe = onCall('),
    );
    expect(source, contains('const requesterId = request.auth?.uid;'));
    expect(
      source,
      contains('readOptionalString(message.sender_id) !== requesterId'),
    );
    expect(source, contains('text: FieldValue.delete()'));
    expect(source, contains('last_message_type: "unsent"'));
    expect(source, contains(r'[`deleted_at_by.${requesterId}`]'));
  });

  test('message rules enforce cutoffs and block client-side mutation', () {
    expect(rules, contains('function canReadConversationMessage'));
    expect(rules, contains('messageData.created_at > cutoff'));
    expect(rules, contains("request.resource.data.type == 'text'"));
    expect(rules, contains('allow update, delete: if false;'));
  });
}
