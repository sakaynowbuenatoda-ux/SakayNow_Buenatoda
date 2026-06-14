import 'package:flutter/material.dart';

class PassengerQuickDestination {
  final String id;
  final String label;
  final String? address;
  final String? pinName;
  final String? pinPlaceId;
  final IconData icon;
  final String? customEmoji;
  final Color accentColor;
  final Color backgroundColor;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const PassengerQuickDestination({
    required this.id,
    required this.label,
    this.address,
    this.pinName,
    this.pinPlaceId,
    required this.icon,
    this.customEmoji,
    required this.accentColor,
    required this.backgroundColor,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasCustomEmoji => customEmoji?.trim().isNotEmpty == true;
  bool get hasSavedLocation =>
      hasCoordinates && locationDisplayLabel != 'Set location';

  String? get pinDisplayLabel {
    final name = pinName?.trim();
    if (name != null && name.isNotEmpty && name != 'Pinned location') {
      return name;
    }

    final placeId = pinPlaceId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      return placeId;
    }

    return null;
  }

  String? get coordinateLabel {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return null;
    }

    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  String get locationDisplayLabel {
    return pinDisplayLabel ?? coordinateLabel ?? 'Set location';
  }

  String get bookingAddress {
    final pinLabel = pinDisplayLabel;
    if (pinLabel != null) {
      return address?.trim().isNotEmpty == true ? address!.trim() : pinLabel;
    }

    return coordinateLabel ??
        (address?.trim().isNotEmpty == true ? address!.trim() : label);
  }

  PassengerQuickDestination copyWith({
    String? id,
    String? label,
    String? address,
    String? pinName,
    String? pinPlaceId,
    bool clearPinDetails = false,
    IconData? icon,
    String? customEmoji,
    bool clearCustomEmoji = false,
    Color? accentColor,
    Color? backgroundColor,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    bool? isDefault,
  }) {
    return PassengerQuickDestination(
      id: id ?? this.id,
      label: label ?? this.label,
      address: clearLocation ? null : address ?? this.address,
      pinName: clearLocation || clearPinDetails
          ? null
          : pinName ?? this.pinName,
      pinPlaceId: clearLocation || clearPinDetails
          ? null
          : pinPlaceId ?? this.pinPlaceId,
      icon: icon ?? this.icon,
      customEmoji: clearCustomEmoji ? null : customEmoji ?? this.customEmoji,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class PassengerTripSummary {
  final String destination;
  final String schedule;
  final DateTime scheduledAt;
  final String fare;
  final String status;
  final double rating;
  final String driverName;

  const PassengerTripSummary({
    required this.destination,
    required this.schedule,
    required this.scheduledAt,
    required this.fare,
    required this.status,
    required this.rating,
    required this.driverName,
  });
}

class PassengerInboxMessage {
  final String senderName;
  final String preview;
  final String timeLabel;
  final bool isUnread;
  final String tag;

  const PassengerInboxMessage({
    required this.senderName,
    required this.preview,
    required this.timeLabel,
    required this.isUnread,
    required this.tag,
  });
}

class PassengerSavedPaymentMethod {
  final String label;
  final String accountName;
  final String lastDigits;
  final IconData icon;
  final Color accentColor;

  const PassengerSavedPaymentMethod({
    required this.label,
    required this.accountName,
    required this.lastDigits,
    required this.icon,
    required this.accentColor,
  });
}

class PassengerInfoStat {
  final String label;
  final String value;
  final IconData icon;

  const PassengerInfoStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class PassengerFareDetail {
  final String label;
  final String value;
  final Color? valueColor;

  const PassengerFareDetail({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class PassengerReferenceData {
  const PassengerReferenceData._();

  static const List<PassengerQuickDestination> quickDestinations =
      <PassengerQuickDestination>[
        PassengerQuickDestination(
          id: 'home',
          label: 'Home',
          icon: Icons.home_rounded,
          accentColor: Color(0xFF030213),
          backgroundColor: Color(0xFFF3F4F6),
          isDefault: true,
        ),
        PassengerQuickDestination(
          id: 'school',
          label: 'School',
          icon: Icons.school_rounded,
          accentColor: Color(0xFF047857),
          backgroundColor: Color(0xFFE7F8EF),
          isDefault: true,
        ),
        PassengerQuickDestination(
          id: 'work',
          label: 'Work',
          icon: Icons.work_rounded,
          accentColor: Color(0xFF2563EB),
          backgroundColor: Color(0xFFEFF6FF),
          isDefault: true,
        ),
      ];

  static final List<PassengerTripSummary> recentTrips = <PassengerTripSummary>[
    PassengerTripSummary(
      destination: 'BCC',
      schedule: 'Apr 16, 2026 - 7:30 AM',
      scheduledAt: DateTime(2026, 4, 16, 7, 30),
      fare: 'PHP 25',
      status: 'completed',
      rating: 5.0,
      driverName: 'Mark Turla',
    ),
    PassengerTripSummary(
      destination: 'Poblacion Home',
      schedule: 'Apr 15, 2026 - 5:10 PM',
      scheduledAt: DateTime(2026, 4, 15, 17, 10),
      fare: 'PHP 25',
      status: 'completed',
      rating: 4.8,
      driverName: 'Ben & Ben',
    ),
    PassengerTripSummary(
      destination: 'Municipal Hall',
      schedule: 'Apr 14, 2026 - 10:40 AM',
      scheduledAt: DateTime(2026, 4, 14, 10, 40),
      fare: 'PHP 25',
      status: 'completed',
      rating: 4.9,
      driverName: 'Jary Estorgio',
    ),
  ];

  static const List<PassengerInboxMessage> inboxMessages =
      <PassengerInboxMessage>[
        PassengerInboxMessage(
          senderName: 'Kathleen Cordero',
          preview:
              'I am near the school gate. Please wait by the covered court.',
          timeLabel: '8:12 AM',
          isUnread: true,
          tag: 'Driver',
        ),
        PassengerInboxMessage(
          senderName: 'SakayNow Support',
          preview: 'Your student discount has been verified for this semester.',
          timeLabel: 'Yesterday',
          isUnread: false,
          tag: 'Support',
        ),
        PassengerInboxMessage(
          senderName: 'Mark Turla',
          preview:
              'Thank you for the ride request. I can pick you up in 3 minutes.',
          timeLabel: 'Tue',
          isUnread: false,
          tag: 'Driver',
        ),
      ];

  static const List<PassengerSavedPaymentMethod> paymentMethods =
      <PassengerSavedPaymentMethod>[
        PassengerSavedPaymentMethod(
          label: 'GCash',
          accountName: 'Noel G.',
          lastDigits: '1298',
          icon: Icons.account_balance_wallet_rounded,
          accentColor: Color(0xFF2F5D7C),
        ),
        PassengerSavedPaymentMethod(
          label: 'Maya',
          accountName: 'Noel G.',
          lastDigits: '4421',
          icon: Icons.payments_rounded,
          accentColor: Color(0xFF174A36),
        ),
      ];

  static const List<PassengerInfoStat> dashboardStats = <PassengerInfoStat>[
    PassengerInfoStat(
      label: 'Completed trips',
      value: '38',
      icon: Icons.route_rounded,
    ),
    PassengerInfoStat(
      label: 'Saved places',
      value: '5',
      icon: Icons.bookmark_rounded,
    ),
    PassengerInfoStat(
      label: 'Average rating',
      value: '4.9',
      icon: Icons.star_rounded,
    ),
    PassengerInfoStat(
      label: 'Cashless ready',
      value: '2 apps',
      icon: Icons.wallet_rounded,
    ),
  ];

  static const List<PassengerFareDetail> fareDetails = <PassengerFareDetail>[
    PassengerFareDetail(label: '1 barangay fare', value: 'PHP 25'),
    PassengerFareDetail(label: 'Up to 5 barangays', value: 'PHP 30'),
    PassengerFareDetail(label: 'Extended route fare', value: 'PHP 30-100'),
    PassengerFareDetail(
      label: 'Buenavista barangays',
      value: '35',
      valueColor: Color(0xFF174A36),
    ),
    PassengerFareDetail(label: 'Cashless payment', value: 'Xendit checkout'),
  ];
}
