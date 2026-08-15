import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('functions/src/index.ts').readAsStringSync();
  });

  test('ride conversations are created by an authenticated callable', () {
    expect(source, contains('export const ensureRideConversation = onCall('));
    expect(source, contains('const requesterId = request.auth?.uid;'));
    expect(source, contains('const bookingId = readRequiredString'));
    expect(source, contains('requesterId !== passengerId'));
    expect(source, contains('requesterId !== driverId'));
  });

  test(
    'ride conversations reuse the latest pair thread and booking history',
    () {
      expect(source, contains('.where("passenger_id", "==", passengerId)'));
      expect(source, contains('.where("driver_id", "==", driverId)'));
      expect(source, contains('selectMostRecentRideConversation(candidates)'));
      expect(
        source,
        contains('canonicalRideConversationId(passengerId, driverId)'),
      );
      expect(source, contains('booking_ids: FieldValue.arrayUnion(bookingId)'));
    },
  );
}
