import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/time_ago_text.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../admin_models.dart';

class AdminSectionIntro extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AdminSectionIntro({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PassengerUi.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.admin_panel_settings_rounded,
            color: PassengerUi.primary,
          ),
        ),
        SizedBox(height: 10),
        Text(title, style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
      ],
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final String? actionLabel;

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final iconSize = compact ? 36.0 : 46.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: PassengerSurfaceCard(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(compact ? 11 : 14),
              ),
              child: Icon(icon, color: accentColor, size: compact ? 20 : 24),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText.copyWith(
                fontSize: compact ? 12.5 : 14,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.sectionTitle.copyWith(
                fontSize: compact ? 17 : 18,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              helper,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText.copyWith(
                fontSize: compact ? 11.5 : 12,
                height: 1.25,
              ),
            ),
            if (onTap != null) ...[
              SizedBox(height: compact ? 8 : 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      actionLabel ?? 'Open queue',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.bodyText.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 11.5 : 13,
                        height: 1.15,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: compact ? 16 : 18,
                    color: accentColor,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminQueueUserTile extends StatelessWidget {
  final AdminUserRecord user;
  final VoidCallback onView;

  const AdminQueueUserTile({
    super.key,
    required this.user,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: [
          _AdminUserAvatar(user: user, radius: 24),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: PassengerUi.cardTitle),
                SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminUserCard._buildChip(
                      user.roleLabel,
                      PassengerUi.dangerSoft,
                      PassengerUi.primary,
                    ),
                    AdminUserCard._buildChip(
                      user.statusLabel,
                      user.statusBackgroundColor,
                      user.statusColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class AdminCapabilityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String status;
  final Color accentColor;

  const AdminCapabilityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PassengerUi.cardTitle),
                SizedBox(height: 4),
                Text(description, style: PassengerUi.bodyText),
                SizedBox(height: 6),
                Text(
                  status,
                  style: PassengerUi.bodyText.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUserCard extends StatelessWidget {
  final AdminUserRecord user;
  final VoidCallback? onTap;
  final String? hintLabel;
  final List<Widget> actions;

  const AdminUserCard({
    super.key,
    required this.user,
    this.onTap,
    this.hintLabel,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final documents = <String>[
      if (user.isPassenger && user.idImageUrl != null) 'ID',
      if (user.selfieUrl != null) 'Selfie',
      if (user.isDriver && user.nbiClearanceUrl != null) 'NBI',
      if (user.isDriver && user.driversLicenseUrl != null) 'License',
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: PassengerSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: PassengerUi.blueSoft,
                  child: _AdminUserAvatar(user: user, radius: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: PassengerUi.cardTitle),
                      SizedBox(height: 2),
                      Text(user.email, style: PassengerUi.bodyText),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            user.roleLabel,
                            PassengerUi.dangerSoft,
                            PassengerUi.primary,
                          ),
                          _buildChip(
                            user.statusLabel,
                            user.statusBackgroundColor,
                            user.statusColor,
                          ),
                          ...documents.map(
                            (document) => _buildChip(
                              document,
                              PassengerUi.mutedSurface,
                              PassengerUi.body,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hintLabel != null && hintLabel!.isNotEmpty) ...[
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hintLabel!,
                      style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: PassengerUi.accentBlue,
                    ),
                ],
              ),
            ],
            if (actions.isNotEmpty) ...[
              SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'A';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class AdminActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  const AdminActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _AdminUserAvatar extends StatelessWidget {
  final AdminUserRecord user;
  final double radius;

  const _AdminUserAvatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.profileImageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: FirebaseStorageImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          fallback: _AdminAvatarFallback(user: user, radius: radius),
        ),
      );
    }

    return _AdminAvatarFallback(user: user, radius: radius);
  }
}

class _AdminAvatarFallback extends StatelessWidget {
  final AdminUserRecord user;
  final double radius;

  const _AdminAvatarFallback({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      child: Text(
        AdminUserCard._initials(user.fullName),
        style: TextStyle(
          color: PassengerUi.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

class AdminBookingCard extends StatelessWidget {
  final AdminBookingRecord booking;
  final String passengerName;
  final String driverName;

  const AdminBookingCard({
    super.key,
    required this.booking,
    required this.passengerName,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$passengerName to ${booking.dropoffLocation}',
                  style: PassengerUi.cardTitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: booking.statusBackgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  booking.statusLabel,
                  style: GoogleFonts.poppins(
                    color: booking.statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _DetailRow(label: 'Pickup', value: booking.pickupLocation),
          _DetailRow(label: 'Drop-off', value: booking.dropoffLocation),
          _DetailRow(label: 'Passenger', value: passengerName),
          _DetailRow(label: 'Driver', value: driverName),
          _DetailRow(
            label: 'Payment',
            value: booking.paymentMethod ?? 'Not set yet',
          ),
          _DetailRow(label: 'Fare', value: booking.fareLabel ?? 'Pending'),
          _DetailTimeRow(label: 'Time', value: booking.timestamp),
        ],
      ),
    );
  }
}

class AdminEmptyCollection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const AdminEmptyCollection({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerEmptyState(
      icon: icon,
      title: title,
      description: description,
    );
  }
}

class AdminErrorCard extends StatelessWidget {
  final String message;

  const AdminErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: PassengerUi.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: PassengerUi.bodyText.copyWith(color: PassengerUi.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminInfoPanel extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const AdminInfoPanel({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PassengerUi.cardTitle),
                SizedBox(height: 6),
                Text(description, style: PassengerUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: PassengerUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value, style: PassengerUi.bodyText)),
        ],
      ),
    );
  }
}

class _DetailTimeRow extends StatelessWidget {
  final String label;
  final DateTime? value;

  const _DetailTimeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: PassengerUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TimeAgoText(dateTime: value, style: PassengerUi.bodyText),
          ),
        ],
      ),
    );
  }
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Waiting for timestamp';
  }

  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '${_monthLabel(value.month)} ${value.day}, ${value.year} - $hour:$minute $period';
}

String _monthLabel(int month) {
  const labels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return labels[month - 1];
}
