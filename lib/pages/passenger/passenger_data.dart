import 'package:flutter/material.dart';

class PassengerQuickDestination {
  final String label;
  final String address;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  const PassengerQuickDestination({
    required this.label,
    required this.address,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });
}

class PassengerTripSummary {
  final String destination;
  final String schedule;
  final String fare;
  final String status;
  final double rating;
  final String driverName;

  const PassengerTripSummary({
    required this.destination,
    required this.schedule,
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
  final Color valueColor;

  const PassengerFareDetail({
    required this.label,
    required this.value,
    this.valueColor = Colors.black,
  });
}

class PassengerMockData {
  const PassengerMockData._();

  static const List<PassengerQuickDestination> quickDestinations =
      <PassengerQuickDestination>[
    PassengerQuickDestination(
      label: 'Home',
      address: 'Poblacion, Buenavista, Bohol',
      icon: Icons.home_rounded,
      accentColor: Color(0xFFB45309),
      backgroundColor: Color(0xFFFFF1DD),
    ),
    PassengerQuickDestination(
      label: 'School',
      address: 'Buenavista National High School',
      icon: Icons.school_rounded,
      accentColor: Color(0xFF0F766E),
      backgroundColor: Color(0xFFDCFCE7),
    ),
    PassengerQuickDestination(
      label: 'Market',
      address: 'Buenavista Public Market',
      icon: Icons.storefront_rounded,
      accentColor: Color(0xFF1D4ED8),
      backgroundColor: Color(0xFFDBEAFE),
    ),
  ];

  static const List<PassengerTripSummary> recentTrips = <PassengerTripSummary>[
    PassengerTripSummary(
      destination: 'Buenavista National High School',
      schedule: 'Apr 16, 2026 - 7:30 AM',
      fare: 'PHP 20',
      status: 'completed',
      rating: 5.0,
      driverName: 'Juan Dela Cruz',
    ),
    PassengerTripSummary(
      destination: 'Poblacion Home',
      schedule: 'Apr 15, 2026 - 5:10 PM',
      fare: 'PHP 20',
      status: 'completed',
      rating: 4.8,
      driverName: 'Pedro Garcia',
    ),
    PassengerTripSummary(
      destination: 'Municipal Hall',
      schedule: 'Apr 14, 2026 - 10:40 AM',
      fare: 'PHP 25',
      status: 'completed',
      rating: 4.9,
      driverName: 'Rogelio Santos',
    ),
  ];

  static const List<PassengerInboxMessage> inboxMessages =
      <PassengerInboxMessage>[
    PassengerInboxMessage(
      senderName: 'Juan Dela Cruz',
      preview: 'I am near the school gate. Please wait by the covered court.',
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
      senderName: 'Pedro Garcia',
      preview: 'Thank you for the ride request. I can pick you up in 3 minutes.',
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
      accentColor: Color(0xFF0057FF),
    ),
    PassengerSavedPaymentMethod(
      label: 'Maya',
      accountName: 'Noel G.',
      lastDigits: '4421',
      icon: Icons.payments_rounded,
      accentColor: Color(0xFF0F9D58),
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
    PassengerFareDetail(label: 'LGU base fare', value: 'PHP 20'),
    PassengerFareDetail(label: 'Extended route fare', value: 'PHP 30'),
    PassengerFareDetail(
      label: 'Student discount',
      value: '20% OFF',
      valueColor: Color(0xFF15803D),
    ),
    PassengerFareDetail(label: 'Cashless payment', value: 'GCash and Maya'),
  ];
}
