enum NotificationSoundEvent {
  standard,
  message,
  bookingAccepted,
  driverArrived,
  bookingRequest,
}

class NotificationSoundProfile {
  static const String payloadKey = 'notification_sound';

  static const String messageKey = 'message';
  static const String bookingAcceptedKey = 'booking_accepted';
  static const String driverArrivedKey = 'driver_arrived';
  static const String bookingRequestKey = 'booking_request';
  static const String standardKey = 'standard';

  static const String messageChannelId = 'sakaynow_messages_sound_v1';
  static const String bookingAcceptedChannelId =
      'sakaynow_booking_accepted_sound_v1';
  static const String driverArrivedChannelId =
      'sakaynow_driver_arrived_sound_v1';
  static const String bookingRequestChannelId =
      'sakaynow_booking_request_sound_v1';

  static const String messageSoundResource = 'sakaynow_message';
  static const String bookingAcceptedSoundResource =
      'sakaynow_booking_accepted';
  static const String driverArrivedSoundResource = 'sakaynow_driver_arrived';
  static const String bookingRequestSoundResource = 'sakaynow_booking_request';

  final NotificationSoundEvent event;

  const NotificationSoundProfile._(this.event);

  static const NotificationSoundProfile standard = NotificationSoundProfile._(
    NotificationSoundEvent.standard,
  );
  static const NotificationSoundProfile message = NotificationSoundProfile._(
    NotificationSoundEvent.message,
  );
  static const NotificationSoundProfile bookingAccepted =
      NotificationSoundProfile._(NotificationSoundEvent.bookingAccepted);
  static const NotificationSoundProfile driverArrived =
      NotificationSoundProfile._(NotificationSoundEvent.driverArrived);
  static const NotificationSoundProfile bookingRequest =
      NotificationSoundProfile._(NotificationSoundEvent.bookingRequest);

  factory NotificationSoundProfile.fromPayload(Map<dynamic, dynamic> data) {
    final explicit = _normalized(data[payloadKey] ?? data['sound_key']);
    final explicitProfile = _fromKey(explicit);
    if (explicitProfile != null) {
      return explicitProfile;
    }

    final type = _normalized(data['type']);
    return switch (type) {
      'chat_message' => message,
      'booking_accepted' => bookingAccepted,
      'driver_arrived' => driverArrived,
      'booking_request' => bookingRequest,
      _ => standard,
    };
  }

  bool get usesCustomSound => event != NotificationSoundEvent.standard;

  String get payloadValue => switch (event) {
    NotificationSoundEvent.message => messageKey,
    NotificationSoundEvent.bookingAccepted => bookingAcceptedKey,
    NotificationSoundEvent.driverArrived => driverArrivedKey,
    NotificationSoundEvent.bookingRequest => bookingRequestKey,
    NotificationSoundEvent.standard => standardKey,
  };

  String? get androidChannelId => switch (event) {
    NotificationSoundEvent.message => messageChannelId,
    NotificationSoundEvent.bookingAccepted => bookingAcceptedChannelId,
    NotificationSoundEvent.driverArrived => driverArrivedChannelId,
    NotificationSoundEvent.bookingRequest => bookingRequestChannelId,
    NotificationSoundEvent.standard => null,
  };

  String? get androidSoundResource => switch (event) {
    NotificationSoundEvent.message => messageSoundResource,
    NotificationSoundEvent.bookingAccepted => bookingAcceptedSoundResource,
    NotificationSoundEvent.driverArrived => driverArrivedSoundResource,
    NotificationSoundEvent.bookingRequest => bookingRequestSoundResource,
    NotificationSoundEvent.standard => null,
  };

  String get androidChannelName => switch (event) {
    NotificationSoundEvent.message => 'Messages with sound',
    NotificationSoundEvent.bookingAccepted => 'Booking accepted alerts',
    NotificationSoundEvent.driverArrived => 'Driver arrival alerts',
    NotificationSoundEvent.bookingRequest => 'Driver booking requests',
    NotificationSoundEvent.standard => 'SakayNow updates',
  };

  String get androidChannelDescription => switch (event) {
    NotificationSoundEvent.message =>
      'Ride chat and support messages with the SakayNow message sound',
    NotificationSoundEvent.bookingAccepted =>
      'Passenger alerts when a driver accepts a booking',
    NotificationSoundEvent.driverArrived =>
      'Passenger alerts when the assigned driver reaches pickup',
    NotificationSoundEvent.bookingRequest =>
      'New ride requests sent to available drivers',
    NotificationSoundEvent.standard => 'General SakayNow notifications',
  };

  String get appleSoundFile {
    final resource = androidSoundResource;
    return resource == null ? 'default' : '$resource.wav';
  }

  static NotificationSoundProfile? _fromKey(String value) {
    return switch (value) {
      messageKey => message,
      bookingAcceptedKey => bookingAccepted,
      driverArrivedKey => driverArrived,
      bookingRequestKey => bookingRequest,
      standardKey => standard,
      _ => null,
    };
  }

  static String _normalized(Object? value) {
    return value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';
  }
}
