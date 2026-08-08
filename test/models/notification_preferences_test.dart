import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/notification_preferences.dart';

void main() {
  test('notification preference field names remain backward compatible', () {
    final preferences = NotificationPreferences.fromMap(const {
      'push_enabled': true,
      'booking_updates_enabled': false,
      'message_updates_enabled': true,
      'account_updates_enabled': false,
      'system_updates_enabled': true,
    });

    expect(preferences.allowsChannel('booking'), isFalse);
    expect(preferences.allowsChannel('message'), isTrue);
    expect(preferences.allowsChannel('account'), isFalse);
    expect(preferences.allowsChannel('system'), isTrue);
    expect(preferences.toMap(), {
      'push_enabled': true,
      'booking_updates_enabled': false,
      'message_updates_enabled': true,
      'account_updates_enabled': false,
      'system_updates_enabled': true,
    });
  });

  test('master push toggle continues to disable every category', () {
    const preferences = NotificationPreferences(pushEnabled: false);

    for (final channel in ['booking', 'message', 'account', 'system']) {
      expect(preferences.allowsChannel(channel), isFalse);
    }
  });
}
