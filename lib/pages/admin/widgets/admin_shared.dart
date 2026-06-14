import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/maps/ride_location_preview_dialog.dart';
import '../../../widgets/time_ago_text.dart';
import '../admin_models.dart';
import 'admin_ui.dart';

export 'admin_ui.dart';

class AdminSectionIntro extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AdminSectionIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions =
            actions.isNotEmpty &&
            constraints.maxWidth.isFinite &&
            constraints.maxWidth < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminUi.soft(AdminUi.accent),
                    borderRadius: AdminUi.radius,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AdminUi.accent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AdminUi.pageTitle)),
                if (actions.isNotEmpty && !stackActions) ...[
                  const SizedBox(width: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: actions),
                ],
              ],
            ),
            if (actions.isNotEmpty && stackActions) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(subtitle!, style: AdminUi.bodyText),
              ),
            ],
          ],
        );
      },
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

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : AdminUi.metricCardMaxWidth;
          final dense = width < 176;
          final veryDense = width < 154;
          final iconSize = dense ? 28.0 : 30.0;
          final contentPadding = EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 11 : 13,
          );
          final lowerText = '$label $helper'.toLowerCase();
          final isPendingOrQueueMetric =
              lowerText.contains('pending') ||
              lowerText.contains('queue') ||
              lowerText.contains('waiting');
          final cardColor = isPendingOrQueueMetric
              ? AdminUi.soft(AdminUi.danger, alpha: 0.025)
              : AdminUi.surface;
          final effectiveAccentColor = isPendingOrQueueMetric
              ? AdminUi.danger
              : accentColor;
          final borderColor = AdminUi.primary.withValues(
            alpha: AdminUi.isDarkMode ? 0.28 : 0.18,
          );

          return MouseRegion(
            cursor: onTap == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: AdminUi.radius,
                child: Ink(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: AdminUi.radius,
                    border: Border.all(color: borderColor),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: AdminUi.isDarkMode ? 0.26 : 0.07,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: effectiveAccentColor.withValues(
                          alpha: isPendingOrQueueMetric
                              ? (AdminUi.isDarkMode ? 0.06 : 0.025)
                              : 0,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: contentPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: iconSize,
                              height: iconSize,
                              decoration: BoxDecoration(
                                color: AdminUi.soft(
                                  effectiveAccentColor,
                                  alpha: 0.12,
                                ),
                                borderRadius: AdminUi.radius,
                                border: Border.all(
                                  color: effectiveAccentColor.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: effectiveAccentColor,
                                size: dense ? 15 : 16,
                              ),
                            ),
                            SizedBox(width: dense ? 7 : 8),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: veryDense ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: AdminUi.labelText.copyWith(
                                  fontSize: dense ? 10.5 : 11,
                                  color: AdminUi.body,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: dense ? 7 : 8),
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AdminUi.valueText.copyWith(
                                  fontSize: dense ? 20 : 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                helper,
                                maxLines: dense ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AdminUi.bodyText.copyWith(
                                  fontSize: dense ? 11 : 11.5,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
    return AdminSurfaceCard(
      child: Row(
        children: [
          _AdminUserAvatar(user: user, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AdminUi.cardTitle),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminUserCard._buildChip(
                      user.roleLabel,
                      AdminUi.soft(AdminUi.neutral),
                      AdminUi.neutral,
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
          const SizedBox(width: 12),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminUi.soft(accentColor),
              borderRadius: AdminUi.radius,
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminUi.cardTitle),
                const SizedBox(height: 4),
                Text(description, style: AdminUi.bodyText),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: AdminUi.bodyText.copyWith(
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

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AdminSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AdminUi.soft(AdminUi.accent),
                    child: _AdminUserAvatar(user: user, radius: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: AdminUi.cardTitle),
                        const SizedBox(height: 2),
                        Text(user.email, style: AdminUi.bodyText),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(
                              user.roleLabel,
                              AdminUi.soft(AdminUi.neutral),
                              AdminUi.neutral,
                            ),
                            _buildChip(
                              user.statusLabel,
                              user.statusBackgroundColor,
                              user.statusColor,
                            ),
                            ...documents.map(
                              (document) => _buildChip(
                                document,
                                AdminUi.mutedSurface,
                                AdminUi.body,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hintLabel!,
                        style: AdminUi.bodyText.copyWith(fontSize: 12.5),
                      ),
                    ),
                    if (onTap != null)
                      Icon(Icons.arrow_forward_rounded, color: AdminUi.accent),
                  ],
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            ],
          ),
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
        border: Border.all(color: fg.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
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
        textStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
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
          color: AdminUi.accent,
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
    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$passengerName to ${booking.dropoffLocation}',
                  style: AdminUi.cardTitle,
                ),
              ),
              if (booking.canPreviewRoute) ...[
                const SizedBox(width: 8),
                RideLocationPreviewButton(
                  pickupLocation: booking.pickupRideLocation!,
                  dropoffLocation: booking.dropoffRideLocation!,
                  color: AdminUi.accentBlue,
                ),
              ],
              const SizedBox(width: 8),
              AdminStatusChip(
                label: booking.statusLabel,
                textColor: booking.statusColor,
                backgroundColor: booking.statusBackgroundColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Pickup', value: booking.pickupLocation),
          _DetailRow(label: 'Drop-off', value: booking.dropoffLocation),
          _DetailRow(label: 'Passenger', value: passengerName),
          _DetailRow(label: 'Driver', value: driverName),
          _DetailRow(
            label: 'Payment',
            value: booking.paymentMethod ?? 'Not set yet',
          ),
          _DetailRow(
            label: 'Payment status',
            value: booking.paymentStatusLabel,
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
    return AdminSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AdminUi.mutedSurface,
              borderRadius: AdminUi.radius,
            ),
            child: Icon(icon, size: 23, color: AdminUi.accent),
          ),
          const SizedBox(height: 12),
          Text(title, style: AdminUi.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            description,
            style: AdminUi.bodyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AdminErrorCard extends StatelessWidget {
  final String message;

  const AdminErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      color: AdminUi.soft(AdminUi.danger, alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AdminUi.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AdminUi.bodyText.copyWith(color: AdminUi.danger),
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
    return AdminSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminUi.soft(accentColor),
              borderRadius: AdminUi.radius,
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminUi.cardTitle),
                const SizedBox(height: 6),
                Text(description, style: AdminUi.bodyText),
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
              style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: AdminUi.bodyText)),
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
              style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TimeAgoText(dateTime: value, style: AdminUi.bodyText),
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
