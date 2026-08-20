import 'package:flutter/material.dart';

import '../../controllers/quick_destinations_controller.dart';
import '../../models/ride_status.dart';
import '../../pages/profile/driver_profile.dart';
import '../../services/ride_tracking_service.dart';
import '../firebase_storage_image.dart';
import '../maps/ride_location_preview_dialog.dart';
import '../time_ago_text.dart';
import '../trip_history_sort.dart';
import 'passenger_ui.dart';

class PassengerRecentTripsSection extends StatelessWidget {
  final String passengerId;
  final int? limit;
  final String title;
  final String actionLabel;
  final VoidCallback? onViewAllTap;
  final QuickDestinationsController? quickDestinationsController;
  final TripHistorySortOption sortOption;

  const PassengerRecentTripsSection({
    super.key,
    required this.passengerId,
    this.limit = 8,
    this.title = 'Recent Trips',
    this.actionLabel = 'View all',
    this.onViewAllTap,
    this.quickDestinationsController,
    this.sortOption = TripHistorySortOption.newest,
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

        final trips = sortTripHistory<PassengerRecentTrip>(
          trips: snapshot.data ?? const <PassengerRecentTrip>[],
          rideOf: (trip) => trip.ride,
          option: sortOption,
        );

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
                    bottom: entry.key == trips.length - 1 ? 0 : 10,
                  ),
                  child: PassengerTripCard(
                    trip: entry.value,
                    passengerId: passengerId,
                    quickDestinationsController: quickDestinationsController,
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
  final QuickDestinationsController? quickDestinationsController;

  const PassengerTripCard({
    super.key,
    required this.trip,
    required this.passengerId,
    this.quickDestinationsController,
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
          horizontal: compact ? 12 : 14,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _DriverAvatar(driver: driver, size: compact ? 42 : 44),
                const SizedBox(width: 9),
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
                                fontSize: compact ? 14 : 15,
                              ),
                            ),
                          ),
                          if (driver.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: PassengerUi.accentBlue,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PassengerStatusChip(
                  label: ride.status.label,
                  dense: true,
                  textColor: ride.status == RideStatus.completed
                      ? PassengerUi.successText
                      : PassengerUi.primary,
                  backgroundColor: ride.status == RideStatus.completed
                      ? PassengerUi.successBackground
                      : PassengerUi.dangerSoft,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _HistoryRouteBlock(
              pickup: ride.pickupLocation.displayLabel,
              dropoff: ride.dropoffLocation.displayLabel,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: PassengerUi.accentBlue,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TimeAgoText(
                    dateTime: ride.updatedAt ?? ride.createdAt,
                    style: PassengerUi.bodyText.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                if (canPreviewRoute || quickDestinationsController != null)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (canPreviewRoute)
                        RideLocationPreviewButton(
                          pickupLocation: ride.pickupLocation,
                          dropoffLocation: ride.dropoffLocation,
                          route: ride.route,
                          dimension: 34,
                          iconSize: 18,
                        ),
                      if (canPreviewRoute &&
                          quickDestinationsController != null)
                        const SizedBox(height: 4),
                      if (quickDestinationsController != null)
                        _SaveToOneTapIconButton(
                          controller: quickDestinationsController!,
                          trip: trip,
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
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

class _SaveToOneTapIconButton extends StatefulWidget {
  final QuickDestinationsController controller;
  final PassengerRecentTrip trip;

  const _SaveToOneTapIconButton({required this.controller, required this.trip});

  @override
  State<_SaveToOneTapIconButton> createState() =>
      _SaveToOneTapIconButtonState();
}

class _SaveToOneTapIconButtonState extends State<_SaveToOneTapIconButton> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isSaved =
            widget.controller.destinationForRideLocation(
              widget.trip.ride.dropoffLocation,
            ) !=
            null;

        return Tooltip(
          message: isSaved
              ? 'Saved to one-tap booking'
              : 'Save to one-tap booking',
          child: IconButton(
            key: ValueKey<String>(
              'save-trip-to-one-tap-${widget.trip.ride.bookingId}',
            ),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            style: IconButton.styleFrom(
              foregroundColor: PassengerUi.accentBlue,
              backgroundColor: PassengerUi.accentBlue.withValues(alpha: 0.10),
              disabledForegroundColor: PassengerUi.successText,
              disabledBackgroundColor: PassengerUi.successBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: isSaved || _isSaving ? null : _saveDestination,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isSaved
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_add_outlined,
                    size: 18,
                  ),
          ),
        );
      },
    );
  }

  Future<void> _saveDestination() async {
    setState(() => _isSaving = true);
    try {
      final destination = await widget.controller.addRideDestination(
        widget.trip.ride.dropoffLocation,
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${destination.label} added to One-tap booking.'),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save destination: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        const SizedBox(height: 4),
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
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: PassengerUi.bodyText.copyWith(fontSize: 12, height: 1.25),
              children: <InlineSpan>[
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: PassengerUi.valueText.copyWith(
                    fontSize: 12,
                    height: 1.25,
                  ),
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
  final double size;

  const _DriverAvatar({required this.driver, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Text(label, style: PassengerUi.valueText.copyWith(fontSize: 12)),
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
        Icon(icon, size: 14, color: PassengerUi.highlightAmber),
        const SizedBox(width: 3),
        Text(label, style: PassengerUi.valueText.copyWith(fontSize: 12)),
      ],
    );
  }
}
