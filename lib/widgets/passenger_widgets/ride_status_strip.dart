import 'package:flutter/material.dart';

import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../maps/map_text_styles.dart';
import 'passenger_ui.dart';

class RideStatusStripForRide extends StatelessWidget {
  final Ride ride;
  final RideTrackingService rideTrackingService;

  RideStatusStripForRide({
    super.key,
    required this.ride,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    final driverId = ride.driverId ?? ride.preferredDriverId;
    final isPendingDriver =
        ride.status == RideStatus.searching && ride.preferredDriverId != null;

    if (driverId == null) {
      return RideStatusStrip(
        status: ride.status,
        isPendingDriver: isPendingDriver,
      );
    }

    return StreamBuilder<DriverReviewProfile>(
      stream: rideTrackingService.watchDriverProfile(driverId),
      builder: (context, snapshot) {
        final driver = snapshot.data;
        return RideStatusStrip(
          status: ride.status,
          isPendingDriver: isPendingDriver,
          driverName: driver?.fullName,
          driverImageUrl: driver?.profileImageUrl,
          driverRatingLabel: driver?.ratingLabel,
          isDriverVerified: driver?.isVerified ?? false,
        );
      },
    );
  }
}

class RideStatusStrip extends StatelessWidget {
  final RideStatus status;
  final bool isPendingDriver;
  final String? driverName;
  final String? driverImageUrl;
  final String? driverRatingLabel;
  final bool isDriverVerified;

  const RideStatusStrip({
    super.key,
    required this.status,
    this.isPendingDriver = false,
    this.driverName,
    this.driverImageUrl,
    this.driverRatingLabel,
    this.isDriverVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasDriver = driverName?.trim().isNotEmpty == true;
    final statusColor = _statusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Row(
        children: <Widget>[
          if (hasDriver) ...<Widget>[
            _DriverAvatar(imageUrl: driverImageUrl, name: driverName!),
            const SizedBox(width: 9),
            Expanded(child: _DriverText(this)),
          ] else ...<Widget>[
            Icon(_statusIcon(status), size: 18, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPendingDriver
                    ? 'Waiting for selected driver'
                    : 'Finding an available driver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MapTextStyles.value.copyWith(fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _StatusPill(label: _statusLabel(status), color: statusColor),
        ],
      ),
    );
  }

  String _statusLabel(RideStatus status) {
    if (status == RideStatus.searching && isPendingDriver) {
      return 'Pending';
    }

    return switch (status) {
      RideStatus.searching => 'Searching',
      RideStatus.accepted => 'Accepted',
      RideStatus.driverArriving => 'On the way',
      RideStatus.arrived => 'Arrived',
      RideStatus.inProgress => 'On trip',
      RideStatus.completed => 'Completed',
      RideStatus.cancelled => 'Cancelled',
    };
  }

  Color _statusColor(RideStatus status) {
    return switch (status) {
      RideStatus.searching => PassengerUi.highlightAmber,
      RideStatus.accepted ||
      RideStatus.driverArriving ||
      RideStatus.arrived ||
      RideStatus.inProgress => PassengerUi.accentBlue,
      RideStatus.completed => PassengerUi.successText,
      RideStatus.cancelled => PassengerUi.primary,
    };
  }

  IconData _statusIcon(RideStatus status) {
    return switch (status) {
      RideStatus.searching => Icons.radar_rounded,
      RideStatus.accepted => Icons.task_alt_rounded,
      RideStatus.driverArriving ||
      RideStatus.arrived ||
      RideStatus.inProgress => Icons.navigation_rounded,
      RideStatus.completed => Icons.check_circle_rounded,
      RideStatus.cancelled => Icons.cancel_rounded,
    };
  }
}

class _DriverText extends StatelessWidget {
  final RideStatusStrip strip;

  const _DriverText(this.strip);

  @override
  Widget build(BuildContext context) {
    final ratingLabel = strip.driverRatingLabel?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                strip.driverName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MapTextStyles.value.copyWith(fontSize: 13),
              ),
            ),
            if (strip.isDriverVerified) ...<Widget>[
              const SizedBox(width: 4),
              Icon(
                Icons.verified_rounded,
                size: 15,
                color: PassengerUi.successText,
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Row(
          children: <Widget>[
            Icon(
              Icons.star_rounded,
              size: 14,
              color: PassengerUi.highlightAmber,
            ),
            const SizedBox(width: 3),
            Text(
              ratingLabel == null || ratingLabel.isEmpty
                  ? 'No ratings yet'
                  : ratingLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MapTextStyles.body.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _DriverAvatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 34,
        height: 34,
        child: FirebaseStorageImage(
          imageUrl: imageUrl,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? 'D' : name[0].toUpperCase(),
              style: TextStyle(
                color: PassengerUi.accentBlue,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: MapTextStyles.value.copyWith(color: color, fontSize: 11.5),
      ),
    );
  }
}
