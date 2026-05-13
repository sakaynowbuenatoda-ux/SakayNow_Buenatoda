import 'package:flutter/material.dart';

import '../../../models/ride.dart';
import '../../../models/ride_status.dart';
import '../../../services/ride_tracking_service.dart';
import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';

class DriverRideRequestCard extends StatelessWidget {
  final Ride ride;
  final bool isAccepting;
  final VoidCallback onAccept;
  final RideTrackingService rideTrackingService;

  DriverRideRequestCard({
    super.key,
    required this.ride,
    required this.isAccepting,
    required this.onAccept,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PassengerReviewProfile>(
      stream: rideTrackingService.watchPassengerProfile(ride.passengerId),
      builder: (context, snapshot) {
        final passenger = snapshot.data;

        return PassengerSurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _PassengerAvatar(profile: passenger),
                  const SizedBox(width: 10),
                  Expanded(child: _PassengerSummary(profile: passenger)),
                  const SizedBox(width: 8),
                  PassengerStatusChip(
                    label: ride.status.label,
                    textColor: PassengerUi.highlightAmber,
                    backgroundColor: PassengerUi.warningSoft,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RouteLine(
                icon: Icons.my_location_rounded,
                iconColor: PassengerUi.secondary,
                label: 'Pickup',
                value: ride.pickupLocation.displayLabel,
              ),
              const SizedBox(height: 8),
              _RouteLine(
                icon: Icons.location_on_rounded,
                iconColor: PassengerUi.primary,
                label: 'Drop-off',
                value: ride.dropoffLocation.displayLabel,
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
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: isAccepting ? null : onAccept,
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
                    label: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
