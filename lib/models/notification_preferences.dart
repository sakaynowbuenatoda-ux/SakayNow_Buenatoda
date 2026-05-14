class NotificationPreferences {
  final bool pushEnabled;
  final bool bookingUpdatesEnabled;
  final bool messageUpdatesEnabled;
  final bool accountUpdatesEnabled;
  final bool systemUpdatesEnabled;

  const NotificationPreferences({
    this.pushEnabled = true,
    this.bookingUpdatesEnabled = true,
    this.messageUpdatesEnabled = true,
    this.accountUpdatesEnabled = true,
    this.systemUpdatesEnabled = true,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> data) {
    return NotificationPreferences(
      pushEnabled: _readBool(data['push_enabled'], fallback: true),
      bookingUpdatesEnabled: _readBool(
        data['booking_updates_enabled'],
        fallback: true,
      ),
      messageUpdatesEnabled: _readBool(
        data['message_updates_enabled'],
        fallback: true,
      ),
      accountUpdatesEnabled: _readBool(
        data['account_updates_enabled'],
        fallback: true,
      ),
      systemUpdatesEnabled: _readBool(
        data['system_updates_enabled'],
        fallback: true,
      ),
    );
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? bookingUpdatesEnabled,
    bool? messageUpdatesEnabled,
    bool? accountUpdatesEnabled,
    bool? systemUpdatesEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      bookingUpdatesEnabled:
          bookingUpdatesEnabled ?? this.bookingUpdatesEnabled,
      messageUpdatesEnabled:
          messageUpdatesEnabled ?? this.messageUpdatesEnabled,
      accountUpdatesEnabled:
          accountUpdatesEnabled ?? this.accountUpdatesEnabled,
      systemUpdatesEnabled: systemUpdatesEnabled ?? this.systemUpdatesEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'push_enabled': pushEnabled,
      'booking_updates_enabled': bookingUpdatesEnabled,
      'message_updates_enabled': messageUpdatesEnabled,
      'account_updates_enabled': accountUpdatesEnabled,
      'system_updates_enabled': systemUpdatesEnabled,
    };
  }

  bool allowsChannel(String channel) {
    if (!pushEnabled) {
      return false;
    }

    return switch (channel.trim().toLowerCase()) {
      'booking' => bookingUpdatesEnabled,
      'message' => messageUpdatesEnabled,
      'account' => accountUpdatesEnabled,
      'review' || 'system' => systemUpdatesEnabled,
      _ => true,
    };
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    final text = value?.toString().trim().toLowerCase();
    if (text == 'true') {
      return true;
    }

    if (text == 'false') {
      return false;
    }

    return fallback;
  }
}
