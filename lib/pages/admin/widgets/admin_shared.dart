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
          final cardColor = AdminUi.isDarkMode && isPendingOrQueueMetric
              ? AdminUi.soft(AdminUi.danger, alpha: 0.025)
              : AdminUi.surface;
          final effectiveAccentColor = isPendingOrQueueMetric
              ? AdminUi.danger
              : accentColor;
          final content = Column(
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
                      color: AdminUi.soft(effectiveAccentColor, alpha: 0.12),
                      borderRadius: AdminUi.radius,
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
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.north_east_rounded,
                      size: 14,
                      color: AdminUi.muted,
                    ),
                  ],
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
                        letterSpacing: -0.35,
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
          );

          if (onTap != null) {
            return AdminInteractiveCard(
              onTap: onTap!,
              padding: contentPadding,
              color: cardColor,
              accentColor: effectiveAccentColor,
              semanticLabel: 'Open $label',
              child: content,
            );
          }

          return AdminSurfaceCard(
            padding: contentPadding,
            color: cardColor,
            child: content,
          );
        },
      ),
    );
  }
}

class AdminQueueUserTile extends StatelessWidget {
  final AdminUserRecord user;
  final VoidCallback onView;
  final String? detail;

  const AdminQueueUserTile({
    super.key,
    required this.user,
    required this.onView,
    this.detail,
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
                if (detail?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.bodyText.copyWith(fontSize: 12.5),
                  ),
                ],
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
  final String title;
  final String description;
  final String status;
  final Color accentColor;

  const AdminCapabilityTile({
    super.key,
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

    final content = Column(
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
            if (onTap != null) ...[
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminUi.soft(AdminUi.accent, alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: AdminUi.accent,
                ),
              ),
            ],
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
            ],
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    );

    if (onTap != null) {
      return AdminInteractiveCard(
        onTap: onTap!,
        accentColor: AdminUi.accent,
        semanticLabel: 'Open ${user.fullName}',
        child: content,
      );
    }

    return AdminSurfaceCard(child: content);
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 620;
          final detailWidth = useTwoColumns
              ? (constraints.maxWidth - 14) / 2
              : constraints.maxWidth;
          final details = <_BookingDetailItem>[
            _BookingDetailItem(label: 'Pickup', value: booking.pickupLocation),
            _BookingDetailItem(
              label: 'Drop-off',
              value: booking.dropoffLocation,
            ),
            _BookingDetailItem(label: 'Passenger', value: passengerName),
            _BookingDetailItem(label: 'Driver', value: driverName),
            _BookingDetailItem(
              label: 'Payment',
              value: booking.paymentMethod ?? 'Not set yet',
            ),
            _BookingDetailItem(
              label: 'Payment status',
              value: booking.paymentStatusLabel,
            ),
            _BookingDetailItem(
              label: 'Fare',
              value: booking.fareLabel ?? 'Pending',
            ),
            if (booking.isCompleted) ...<_BookingDetailItem>[
              _BookingDetailItem(
                label: 'Gross fare',
                value: 'PHP ${booking.grossFareAmount}',
              ),
              _BookingDetailItem(
                label: 'Commission (${booking.commissionRateLabel})',
                value: 'PHP ${booking.commissionAmount}',
              ),
              _BookingDetailItem(
                label: 'Driver net earnings',
                value: 'PHP ${booking.driverNetEarnings}',
              ),
              _BookingDetailItem(
                label: 'Payout status',
                value: booking.driverPayoutStatusLabel,
              ),
            ],
            _BookingDetailItem.time(time: booking.timestamp),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BookingCardHeader(
                booking: booking,
                passengerName: passengerName,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: details
                    .map(
                      (detail) => SizedBox(
                        width: detailWidth,
                        child: _BookingDetailTile(detail: detail),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingCardHeader extends StatelessWidget {
  final AdminBookingRecord booking;
  final String passengerName;

  const _BookingCardHeader({
    required this.booking,
    required this.passengerName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final title = Text(
          '$passengerName to ${booking.dropoffLocation}',
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: AdminUi.cardTitle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AdminUi.title,
          ),
        );
        final actions = <Widget>[
          if (booking.canPreviewRoute)
            RideLocationPreviewButton(
              pickupLocation: booking.pickupRideLocation!,
              dropoffLocation: booking.dropoffRideLocation!,
              route: booking.route,
              color: AdminUi.accentBlue,
              dimension: 38,
              iconSize: 19,
            ),
          if (booking.canPreviewRoute) const SizedBox(width: 8),
          AdminStatusChip(
            label: booking.statusLabel,
            textColor: booking.statusColor,
            backgroundColor: booking.statusBackgroundColor,
          ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 12),
            ...actions,
          ],
        );
      },
    );
  }
}

class _BookingDetailItem {
  final String label;
  final String? value;
  final DateTime? time;

  const _BookingDetailItem({required this.label, required String this.value})
    : time = null;

  const _BookingDetailItem.time({required this.time})
    : label = 'Time',
      value = null;
}

class _BookingDetailTile extends StatelessWidget {
  final _BookingDetailItem detail;

  const _BookingDetailTile({required this.detail});

  @override
  Widget build(BuildContext context) {
    final valueStyle = AdminUi.bodyText.copyWith(
      color: AdminUi.title,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          detail.label,
          style: AdminUi.labelText.copyWith(
            color: AdminUi.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        if (detail.time != null)
          TimeAgoText(dateTime: detail.time, style: valueStyle)
        else
          Text(detail.value!, style: valueStyle),
      ],
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

  const AdminInfoPanel({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Waiting for timestamp';
  }

  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '${_monthLabel(value.month)} ${value.day}, ${value.year} - $hour:$minute $period';
}

String formatDate(DateTime? value) {
  if (value == null) {
    return 'Not recorded';
  }

  return '${_monthLabel(value.month)} ${value.day}, ${value.year}';
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
