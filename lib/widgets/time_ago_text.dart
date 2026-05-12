import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

class TimeAgoText extends StatelessWidget {
  final DateTime? dateTime;
  final String? dateTimeText;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const TimeAgoText({
    super.key,
    this.dateTime,
    this.dateTimeText,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      TimeAgo.format(dateTime ?? TimeAgo.tryParse(dateTimeText)),
      style: style ?? PassengerUi.bodyText,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class TimeAgo {
  const TimeAgo._();

  static String format(DateTime? value, {DateTime? now}) {
    if (value == null) {
      return 'Recently';
    }

    final current = now ?? DateTime.now();
    final difference = current.difference(value);

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inSeconds < 45) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return _unit(difference.inMinutes, 'min');
    }

    if (difference.inHours < 24) {
      return _unit(difference.inHours, 'hr');
    }

    if (difference.inDays < 7) {
      return _unit(difference.inDays, 'day');
    }

    if (difference.inDays < 30) {
      return _unit((difference.inDays / 7).floor(), 'week');
    }

    if (difference.inDays < 365) {
      return _unit((difference.inDays / 30).floor(), 'month');
    }

    return _unit((difference.inDays / 365).floor(), 'year');
  }

  static DateTime? tryParse(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll(' - ', ' ');
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length < 5) {
      return DateTime.tryParse(text);
    }

    final month = _month(parts[0]);
    final day = int.tryParse(parts[1].replaceAll(',', ''));
    final year = int.tryParse(parts[2]);
    var hour = int.tryParse(parts[3].split(':').first);
    final minute = int.tryParse(parts[3].split(':').last);
    final period = parts[4].toUpperCase();

    if (month == null ||
        day == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return DateTime.tryParse(text);
    }

    if (period == 'PM' && hour < 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(year, month, day, hour, minute);
  }

  static String _unit(int value, String unit) {
    final safeValue = value <= 0 ? 1 : value;
    return '$safeValue $unit${safeValue == 1 ? '' : 's'} ago';
  }

  static int? _month(String value) {
    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    return months[value.toLowerCase()];
  }
}
