import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String functionsSource;

  setUpAll(() {
    functionsSource = File('functions/src/index.ts').readAsStringSync();
  });

  test('push payloads use event-specific Android and Apple sounds', () {
    expect(functionsSource, contains('function notificationSoundProfile('));
    expect(functionsSource, contains('case "chat_message":'));
    expect(functionsSource, contains('case "booking_accepted":'));
    expect(functionsSource, contains('case "driver_arrived":'));
    expect(functionsSource, contains('case "booking_request":'));
    expect(functionsSource, contains('sakaynow_messages_sound_v1'));
    expect(functionsSource, contains('sakaynow_booking_accepted_sound_v1'));
    expect(functionsSource, contains('sakaynow_driver_arrived_sound_v1'));
    expect(functionsSource, contains('sakaynow_booking_request_sound_v1'));
    expect(functionsSource, contains('sound: soundProfile.androidSound'));
    expect(functionsSource, contains('sound: soundProfile.appleSound'));
  });

  test('foreground payload data carries the selected sound key', () {
    expect(functionsSource, contains('notification_sound: soundProfile.key'));
    expect(
      functionsSource,
      contains('notificationSoundProfile("chat_message", "message")'),
    );
  });
}
