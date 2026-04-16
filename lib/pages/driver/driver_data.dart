import 'package:flutter/material.dart';

class DriverQueueItem {
  final String passengerName;
  final String pickup;
  final String dropoff;
  final String requestedAt;
  final String fare;
  final String status;

  const DriverQueueItem({
    required this.passengerName,
    required this.pickup,
    required this.dropoff,
    required this.requestedAt,
    required this.fare,
    required this.status,
  });
}

class DriverMessageSummary {
  final String senderName;
  final String preview;
  final String timeLabel;
  final bool isUnread;

  const DriverMessageSummary({
    required this.senderName,
    required this.preview,
    required this.timeLabel,
    required this.isUnread,
  });
}

class DriverTripSummary {
  final String passengerName;
  final String route;
  final String completedAt;
  final String earnings;
  final double rating;

  const DriverTripSummary({
    required this.passengerName,
    required this.route,
    required this.completedAt,
    required this.earnings,
    required this.rating,
  });
}

class DriverInfoStat {
  final String label;
  final String value;
  final IconData icon;

  const DriverInfoStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class DriverMockData {
  const DriverMockData._();

  static const List<DriverQueueItem> queue = <DriverQueueItem>[
    DriverQueueItem(
      passengerName: 'Maria Santos',
      pickup: 'Buenavista National High School',
      dropoff: 'Poblacion, Buenavista',
      requestedAt: 'Requested 7:42 AM',
      fare: 'PHP 20',
      status: 'new',
    ),
    DriverQueueItem(
      passengerName: 'Carlo Reyes',
      pickup: 'Public Market',
      dropoff: 'Municipal Hall',
      requestedAt: 'Requested 7:48 AM',
      fare: 'PHP 25',
      status: 'queued',
    ),
  ];

  static const List<DriverMessageSummary> messages = <DriverMessageSummary>[
    DriverMessageSummary(
      senderName: 'Maria Santos',
      preview: 'I am at the school gate near the waiting shed.',
      timeLabel: '8:03 AM',
      isUnread: true,
    ),
    DriverMessageSummary(
      senderName: 'SakayNow Support',
      preview: 'Your profile review is complete. Keep your documents updated.',
      timeLabel: 'Yesterday',
      isUnread: false,
    ),
  ];

  static const List<DriverTripSummary> history = <DriverTripSummary>[
    DriverTripSummary(
      passengerName: 'Ana Lopez',
      route: 'Public Market to Poblacion',
      completedAt: 'Apr 16, 2026 - 6:55 AM',
      earnings: 'PHP 20',
      rating: 5.0,
    ),
    DriverTripSummary(
      passengerName: 'John Perez',
      route: 'Municipal Hall to School',
      completedAt: 'Apr 15, 2026 - 4:25 PM',
      earnings: 'PHP 25',
      rating: 4.8,
    ),
  ];

  static const List<DriverInfoStat> stats = <DriverInfoStat>[
    DriverInfoStat(
      label: 'Today earnings',
      value: 'PHP 340',
      icon: Icons.payments_rounded,
    ),
    DriverInfoStat(
      label: 'Completed rides',
      value: '16',
      icon: Icons.route_rounded,
    ),
    DriverInfoStat(
      label: 'Acceptance rate',
      value: '93%',
      icon: Icons.check_circle_rounded,
    ),
    DriverInfoStat(
      label: 'Average rating',
      value: '4.9',
      icon: Icons.star_rounded,
    ),
  ];
}
