import 'package:flutter/material.dart';

import '../../models/ride_status.dart';
import '../../pages/profile/driver_profile.dart';
import '../../services/ride_tracking_service.dart';
import '../firebase_storage_image.dart';
import '../maps/ride_location_preview_dialog.dart';
import '../time_ago_text.dart';
import 'passenger_ui.dart';

class PassengerRecentTripsSection extends StatelessWidget {
  final String passengerId;
  final int limit;
  final String title;
  final String actionLabel;
  final VoidCallback? onViewAllTap;

  const PassengerRecentTripsSection({
    super.key,
    required this.passengerId,
    this.limit = 8,
    this.title = 'Recent Trips',
    this.actionLabel = 'View all',
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PassengerRecentTrip>>(
      stream: RideTrackingService().watchPassengerRecentTrips(
        passengerId,
        limit: limit,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PassengerSectionHeader(
                title: title,
                actionLabel: actionLabel,
                onActionTap: onViewAllTap,
              ),
              const SizedBox(height: 14),
              const SizedBox(
                height: 126,
                child: PassengerSurfaceCard(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PassengerSectionHeader(
                title: title,
                actionLabel: actionLabel,
                onActionTap: onViewAllTap,
              ),
              const SizedBox(height: 14),
              PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load trips',
                description:
                    'Recent trips could not be loaded. Please try again.',
              ),
            ],
          );
        }

        final trips = snapshot.data ?? const <PassengerRecentTrip>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerSectionHeader(
              title: title,
              actionLabel: actionLabel,
              onActionTap: onViewAllTap,
            ),
            const SizedBox(height: 14),
            if (trips.isEmpty)
              const PassengerEmptyState(
                icon: Icons.history_rounded,
                title: 'No recent trips',
                description:
                    'Completed and cancelled trips with drivers will appear here.',
              )
            else
              ...trips.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == trips.length - 1 ? 0 : 12,
                  ),
                  child: PassengerTripCard(
                    trip: entry.value,
                    passengerId: passengerId,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PassengerTripCard extends StatelessWidget {
  final PassengerRecentTrip trip;
  final String passengerId;

  const PassengerTripCard({
    super.key,
    required this.trip,
    required this.passengerId,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final ride = trip.ride;
    final driver = trip.driver;
    final passengerHasReviewedDriver = ride.hasPassengerDriverReview;
    final passengerHasReviewComment =
        ride.passengerDriverReviewComment?.trim().isNotEmpty == true;
    final canPassengerReviewDriver = ride.canPassengerReviewDriver;
    final passengerReviewLabel = _passengerReviewLabel(
      hasReview: passengerHasReviewedDriver,
      hasComment: passengerHasReviewComment,
      canReview: canPassengerReviewDriver,
    );
    final canPreviewRoute =
        ride.pickupLocation.latLng != null &&
        ride.dropoffLocation.latLng != null;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverProfilePage(
            driverId: driver.driverId,
            passengerId: passengerId,
            bookingId: ride.bookingId,
            openReviewOnLoad: canPassengerReviewDriver,
          ),
        ),
      ),
      child: PassengerSurfaceCard(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 14 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _DriverAvatar(driver: driver),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              driver.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PassengerUi.cardTitle.copyWith(
                                fontSize: compact ? 15 : 16,
                              ),
                            ),
                          ),
                          if (driver.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified_rounded,
                              size: 17,
                              color: PassengerUi.accentBlue,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PassengerStatusChip(
                  label: ride.status.label,
                  textColor: ride.status == RideStatus.completed
                      ? PassengerUi.successText
                      : PassengerUi.primary,
                  backgroundColor: ride.status == RideStatus.completed
                      ? PassengerUi.successBackground
                      : PassengerUi.dangerSoft,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _HistoryRouteBlock(
              pickup: ride.pickupLocation.displayLabel,
              dropoff: ride.dropoffLocation.displayLabel,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: PassengerUi.accentBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TimeAgoText(
                    dateTime: ride.updatedAt ?? ride.createdAt,
                    style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (canPreviewRoute) ...<Widget>[
                  RideLocationPreviewButton(
                    pickupLocation: ride.pickupLocation,
                    dropoffLocation: ride.dropoffLocation,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _InfoPill(label: ride.fareLabel ?? 'Fare pending'),
                if (ride.distanceLabel != 'Calculating')
                  _InfoPill(label: ride.distanceLabel),
                _RatingPill(
                  icon: Icons.star_rounded,
                  label: driver.reviewCount == 0
                      ? 'No driver rating'
                      : driver.averageRating.toStringAsFixed(1),
                ),
                _RatingPill(
                  icon: !passengerHasReviewedDriver && canPassengerReviewDriver
                      ? Icons.rate_review_outlined
                      : Icons.rate_review_rounded,
                  label: passengerReviewLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _passengerReviewLabel({
    required bool hasReview,
    required bool hasComment,
    required bool canReview,
  }) {
    if (hasReview) {
      return hasComment ? 'Commented' : 'No comment';
    }

    return canReview ? 'Tap to review' : 'No comment';
  }
}

class _HistoryRouteBlock extends StatelessWidget {
  final String pickup;
  final String dropoff;

  const _HistoryRouteBlock({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _HistoryLocationLine(
          icon: Icons.my_location_rounded,
          iconColor: PassengerUi.secondary,
          label: 'Pickup',
          value: pickup,
        ),
        const SizedBox(height: 7),
        _HistoryLocationLine(
          icon: Icons.location_on_rounded,
          iconColor: PassengerUi.primary,
          label: 'Drop-off',
          value: dropoff,
        ),
      ],
    );
  }
}

class _HistoryLocationLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _HistoryLocationLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
              children: <InlineSpan>[
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: PassengerUi.valueText.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final DriverReviewProfile driver;

  const _DriverAvatar({required this.driver});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 50,
        height: 50,
        child: FirebaseStorageImage(
          imageUrl: driver.profileImageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(driver.fullName),
              style: PassengerUi.valueText.copyWith(
                color: PassengerUi.accentBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'D';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Text(label, style: PassengerUi.valueText.copyWith(fontSize: 13)),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RatingPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: PassengerUi.highlightAmber),
        const SizedBox(width: 4),
        Text(label, style: PassengerUi.valueText.copyWith(fontSize: 13)),
      ],
    );
  }
}
