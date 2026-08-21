import 'package:flutter/material.dart';

import '../../../models/ride.dart';
import '../../../services/booking_action_cooldown_service.dart';
import '../../../services/ride_tracking_service.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/maps/ride_location_preview_dialog.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../../../widgets/reports/report_user_sheet.dart';
import '../../profile/passenger_profile.dart';

class DriverRideRequestCard extends StatelessWidget {
  final Ride ride;
  final String driverId;
  final bool isAccepting;
  final bool isDeclining;
  final Duration acceptCooldownRemaining;
  final bool canAcceptDeclined;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final RideTrackingService rideTrackingService;

  DriverRideRequestCard({
    super.key,
    required this.ride,
    required this.driverId,
    required this.isAccepting,
    required this.isDeclining,
    required this.acceptCooldownRemaining,
    this.canAcceptDeclined = false,
    required this.onAccept,
    required this.onDecline,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    final isBusy = isAccepting || isDeclining;
    final isAcceptCoolingDown = acceptCooldownRemaining > Duration.zero;
    final hasDeclined = ride.declinedDriverIds.contains(driverId);
    final requestLabel = hasDeclined
        ? 'Declined'
        : ride.preferredDriverId == driverId
        ? 'Requested you'
        : 'Open request';
    final canPreviewRoute =
        ride.pickupLocation.latLng != null &&
        ride.dropoffLocation.latLng != null;

    return StreamBuilder<PassengerReviewProfile>(
      stream: rideTrackingService.watchPassengerProfile(ride.passengerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppSkeletonCard(showAvatar: true, lineCount: 4);
        }

        final passenger = snapshot.data;

        return PassengerSurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: ride.passengerId.trim().isEmpty
                          ? null
                          : () => _openPassengerProfile(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            _PassengerAvatar(profile: passenger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PassengerSummary(profile: passenger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PassengerStatusChip(
                    label: requestLabel,
                    textColor: hasDeclined
                        ? PassengerUi.primary
                        : PassengerUi.highlightAmber,
                    backgroundColor: hasDeclined
                        ? PassengerUi.dangerSoft
                        : PassengerUi.warningSoft,
                  ),
                  if (passenger != null) ...<Widget>[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _reportPassenger(context, passenger),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: PassengerUi.dangerSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: PassengerUi.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.report_gmailerrorred_rounded,
                              size: 14,
                              color: PassengerUi.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Report',
                              style: PassengerUi.valueText.copyWith(
                                fontSize: 11,
                                color: PassengerUi.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _RouteLine(
                icon: Icons.my_location_rounded,
                iconColor: PassengerUi.secondary,
                label: 'Pickup',
                value: ride.pickupLocation.publicDisplayLabel,
              ),
              const SizedBox(height: 8),
              _RouteLine(
                icon: Icons.location_on_rounded,
                iconColor: PassengerUi.primary,
                label: 'Drop-off',
                value: ride.dropoffLocation.publicDisplayLabel,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _RideValuePill(
                      icon: Icons.payments_rounded,
                      label: ride.fareLabel ?? 'Fare pending',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RideValuePill(
                      icon: Icons.account_balance_wallet_rounded,
                      label: ride.paymentMethodDisplayLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: PassengerUi.accentBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ride.etaLabel} estimate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.bodyText.copyWith(fontSize: 13),
                    ),
                  ),
                  if (canPreviewRoute) ...<Widget>[
                    const SizedBox(width: 8),
                    RideLocationPreviewButton(
                      pickupLocation: ride.pickupLocation,
                      dropoffLocation: ride.dropoffLocation,
                      route: ride.route,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (hasDeclined) ...<Widget>[
                _DeclinedRequestNotice(canAccept: canAcceptDeclined),
                if (canAcceptDeclined) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isBusy || isAcceptCoolingDown
                          ? null
                          : onAccept,
                      icon: isAccepting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        isAcceptCoolingDown
                            ? 'Wait ${BookingActionCooldownService.formatRemaining(acceptCooldownRemaining)}'
                            : 'Accept request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ] else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : onDecline,
                        icon: isDeclining
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PassengerUi.primary,
                                ),
                              )
                            : const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isBusy || isAcceptCoolingDown
                            ? null
                            : onAccept,
                        icon: isAccepting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          isAcceptCoolingDown
                              ? 'Wait ${BookingActionCooldownService.formatRemaining(acceptCooldownRemaining)}'
                              : 'Accept',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _openPassengerProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassengerProfilePage(
          passengerId: ride.passengerId,
          driverId: driverId,
          bookingId: ride.bookingId,
        ),
      ),
    );
  }

  Future<void> _reportPassenger(
    BuildContext context,
    PassengerReviewProfile passenger,
  ) async {
    final draft = await showUserReportSheet(
      context,
      title: 'Report ${passenger.fullName}',
      reasons: const <String>[
        'Safety concern',
        'No-show or unreachable',
        'Incorrect pickup details',
        'Unprofessional behavior',
        'Payment concern',
        'Other',
      ],
    );
    if (draft == null) {
      return;
    }
    try {
      await rideTrackingService.reportPassenger(
        bookingId: ride.bookingId,
        driverId: driverId,
        passengerId: passenger.userId,
        reason: draft.reason,
        details: draft.details,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for admin review.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to submit report: $error')),
        );
      }
    }
  }
}

class _DeclinedRequestNotice extends StatelessWidget {
  final bool canAccept;

  const _DeclinedRequestNotice({required this.canAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.block_rounded, size: 17, color: PassengerUi.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              canAccept
                  ? 'Declined by you. You can still accept it here.'
                  : 'Declined by you. Still open in the queue.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideValuePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RideValuePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: PassengerUi.accentBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.valueText.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerSummary extends StatelessWidget {
  final PassengerReviewProfile? profile;

  const _PassengerSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final passenger = profile;
    final name = passenger?.fullName ?? 'Passenger';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PassengerUi.cardTitle.copyWith(fontSize: 15),
              ),
            ),
            if (passenger?.isVerified == true) ...<Widget>[
              const SizedBox(width: 5),
              Icon(
                Icons.verified_rounded,
                size: 16,
                color: PassengerUi.accentBlue,
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: <Widget>[
            Icon(
              Icons.star_rounded,
              size: 15,
              color: PassengerUi.highlightAmber,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                passenger?.ratingLabel ?? 'Loading rating',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PassengerUi.bodyText.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PassengerAvatar extends StatelessWidget {
  final PassengerReviewProfile? profile;

  const _PassengerAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final passenger = profile;

    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: FirebaseStorageImage(
          imageUrl: passenger?.profileImageUrl,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(passenger?.fullName ?? 'Passenger'),
              style: PassengerUi.valueText.copyWith(
                color: PassengerUi.accentBlue,
                fontSize: 13,
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
      return 'P';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _RouteLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RouteLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: PassengerUi.bodyText.copyWith(fontSize: 13),
              children: <InlineSpan>[
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: PassengerUi.valueText.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
