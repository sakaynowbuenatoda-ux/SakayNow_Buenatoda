import 'package:flutter/material.dart';

import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../pages/messages/ride_chat_navigation.dart';
import '../../pages/profile/driver_profile.dart';
import '../../services/paymongo_checkout_service.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/maps/map_text_styles.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/passenger_widgets/ride_status_strip.dart';

class RideMonitoringPage extends StatefulWidget {
  final String bookingId;
  final String userId;
  final RideViewerRole viewerRole;

  const RideMonitoringPage({
    super.key,
    required this.bookingId,
    required this.userId,
    required this.viewerRole,
  });

  @override
  State<RideMonitoringPage> createState() => _RideMonitoringPageState();
}

class _RideMonitoringPageState extends State<RideMonitoringPage> {
  late final RideTrackingController _controller;
  final PayMongoCheckoutService _payMongoCheckoutService =
      PayMongoCheckoutService();
  bool _completionDialogShown = false;
  bool _isOpeningCheckout = false;

  @override
  void initState() {
    super.initState();
    _controller = RideTrackingController(
      bookingId: widget.bookingId,
      userId: widget.userId,
      viewerRole: widget.viewerRole,
    );
    _controller.addListener(_handleRideUpdates);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleRideUpdates);
    _controller.dispose();
    super.dispose();
  }

  void _handleRideUpdates() {
    final ride = _controller.ride;
    if (_completionDialogShown ||
        !_controller.isPassenger ||
        ride == null ||
        ride.status != RideStatus.completed) {
      return;
    }

    _completionDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showRideCompletedDialog(ride);
    });
  }

  Future<void> _showRideCompletedDialog(Ride ride) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _RideCompletedDialog(
          ride: ride,
          onClose: () => Navigator.of(dialogContext).pop(),
          onRateReview: ride.hasDriver
              ? () {
                  Navigator.of(dialogContext).pop();
                  if (!mounted) {
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DriverProfilePage(
                        driverId: ride.driverId!,
                        passengerId: widget.userId,
                        bookingId: ride.bookingId,
                        openReviewOnLoad: true,
                      ),
                    ),
                  );
                }
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.background,
        surfaceTintColor: PassengerUi.background,
        title: Text('Ride Monitoring', style: MapTextStyles.title),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final ride = _controller.ride;
          if (ride == null) {
            return Padding(
              padding: PassengerUi.pagePadding(context),
              child: const PassengerEmptyState(
                icon: Icons.route_rounded,
                title: 'Ride not found',
                description: 'This booking may have been removed or expired.',
              ),
            );
          }

          return SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: PassengerUi.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PassengerPageHeader(
                    title: ride.status.label,
                    subtitle: _statusSubtitle(ride),
                    icon: Icons.route_rounded,
                    accentColor: _statusColor(ride.status),
                  ),
                  const SizedBox(height: 16),
                  PassengerSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: PassengerUi.cardRadius,
                      child: SizedBox(
                        height: 330,
                        child: SakayGoogleMap(
                          initialCameraTarget: _controller.initialCameraTarget,
                          bounds: _controller.visibleBounds,
                          markers: _controller.markers,
                          polylines: _controller.polylines,
                          circles: _controller.circles,
                          myLocationEnabled: _controller.isDriver,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RideStatusStripForRide(ride: ride),
                  const SizedBox(height: 16),
                  _RideEtaCard(ride: ride),
                  const SizedBox(height: 16),
                  _RideRouteCard(ride: ride),
                  const SizedBox(height: 16),
                  _RidePaymentCard(
                    ride: ride,
                    canOpenCheckout: _controller.isPassenger,
                    isOpeningCheckout: _isOpeningCheckout,
                    onOpenCheckout: () => _openPayMongoCheckout(ride),
                  ),
                  if (_controller.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    PassengerSurfaceCard(
                      child: Text(
                        _controller.errorMessage!,
                        style: MapTextStyles.body.copyWith(
                          color: PassengerUi.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _RideActions(controller: _controller, ride: ride),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _statusSubtitle(Ride ride) {
    switch (ride.status) {
      case RideStatus.searching:
        return 'Waiting for a verified driver to accept this booking.';
      case RideStatus.accepted:
        return 'Driver accepted the booking and can start heading to pickup.';
      case RideStatus.driverArriving:
        return 'Driver location updates are shown on the map in real time.';
      case RideStatus.arrived:
        return 'Driver has arrived at the pickup radius.';
      case RideStatus.inProgress:
        return 'Trip is active. Remaining distance and ETA update while moving.';
      case RideStatus.completed:
        return 'Trip completed successfully.';
      case RideStatus.cancelled:
        return 'This booking has been cancelled.';
    }
  }

  Color _statusColor(RideStatus status) {
    return switch (status) {
      RideStatus.completed => PassengerUi.successText,
      RideStatus.cancelled => PassengerUi.primary,
      RideStatus.searching => PassengerUi.highlightAmber,
      _ => PassengerUi.accentBlue,
    };
  }

  Future<void> _openPayMongoCheckout(Ride ride) async {
    final checkoutUrl = ride.payMongoCheckoutUrl;
    if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PayMongo checkout is not ready yet.')),
      );
      return;
    }

    setState(() => _isOpeningCheckout = true);
    try {
      await _payMongoCheckoutService.openCheckoutUrl(checkoutUrl);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open checkout: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningCheckout = false);
      }
    }
  }
}

class _RideEtaCard extends StatelessWidget {
  final Ride ride;

  const _RideEtaCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          _RideMetricTile(
            icon: Icons.access_time_rounded,
            label: ride.status == RideStatus.inProgress
                ? 'Destination ETA'
                : 'Pickup ETA',
            value: ride.etaLabel,
          ),
          Container(width: 1, height: 42, color: PassengerUi.border),
          _RideMetricTile(
            icon: Icons.social_distance_rounded,
            label: 'Distance',
            value: ride.distanceLabel,
          ),
        ],
      ),
    );
  }
}

class _RideMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RideMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: <Widget>[
          Icon(icon, color: PassengerUi.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: MapTextStyles.body.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideRouteCard extends StatelessWidget {
  final Ride ride;

  const _RideRouteCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        children: <Widget>[
          _LocationRow(
            icon: Icons.my_location_rounded,
            iconColor: PassengerUi.secondary,
            label: 'Pickup',
            value: ride.pickupLocation.displayLabel,
          ),
          const SizedBox(height: 12),
          _LocationRow(
            icon: Icons.location_on_rounded,
            iconColor: PassengerUi.primary,
            label: 'Drop-off',
            value: ride.dropoffLocation.displayLabel,
          ),
        ],
      ),
    );
  }
}

class _RidePaymentCard extends StatelessWidget {
  final Ride ride;
  final bool canOpenCheckout;
  final bool isOpeningCheckout;
  final VoidCallback onOpenCheckout;

  const _RidePaymentCard({
    required this.ride,
    required this.canOpenCheckout,
    required this.isOpeningCheckout,
    required this.onOpenCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final showCheckoutButton =
        canOpenCheckout && ride.usesPayMongo && !ride.isPaymentPaid;

    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _RidePaymentMetric(
                  icon: Icons.payments_rounded,
                  label: 'Fare',
                  value: ride.fareLabel ?? 'Pending',
                ),
              ),
              Container(width: 1, height: 42, color: PassengerUi.border),
              Expanded(
                child: _RidePaymentMetric(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Payment',
                  value: ride.paymentMethodDisplayLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              PassengerStatusChip(
                label: ride.paymentStatusLabel,
                textColor: ride.isPaymentPaid
                    ? PassengerUi.successText
                    : PassengerUi.highlightAmber,
                backgroundColor: ride.isPaymentPaid
                    ? PassengerUi.successBackground
                    : PassengerUi.warningSoft,
              ),
              if (showCheckoutButton) ...<Widget>[
                const Spacer(),
                TextButton.icon(
                  onPressed: isOpeningCheckout ? null : onOpenCheckout,
                  icon: isOpeningCheckout
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Checkout'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RidePaymentMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RidePaymentMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: PassengerUi.accentBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: MapTextStyles.body.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MapTextStyles.value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideCompletedDialog extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onRateReview;
  final VoidCallback onClose;

  const _RideCompletedDialog({
    required this.ride,
    required this.onRateReview,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PassengerUi.border),
            boxShadow: PassengerUi.cardShadow,
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 18 : 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: PassengerUi.successBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: PassengerUi.successText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ride Complete',
                        style: PassengerUi.sectionTitle.copyWith(
                          fontSize: compact ? 19 : 21,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _RideCompleteDetailRow(
                  icon: Icons.my_location_rounded,
                  label: 'Pickup',
                  value: ride.pickupLocation.displayLabel,
                ),
                const SizedBox(height: 12),
                _RideCompleteDetailRow(
                  icon: Icons.location_on_rounded,
                  label: 'Drop-off',
                  value: ride.dropoffLocation.displayLabel,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _RideCompleteMetric(
                        label: 'Distance',
                        value: ride.distanceLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RideCompleteMetric(
                        label: 'Fare',
                        value: ride.fareLabel ?? 'Pending',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onClose,
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onRateReview,
                        icon: const Icon(Icons.rate_review_rounded, size: 18),
                        label: const Text('Rate / Review'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideCompleteDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RideCompleteDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: PassengerUi.mutedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: PassengerUi.accentBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: PassengerUi.bodyText.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: PassengerUi.valueText),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideCompleteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _RideCompleteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: PassengerUi.bodyText.copyWith(fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PassengerUi.valueText,
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _LocationRow({
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
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: MapTextStyles.body.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: MapTextStyles.value),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideActions extends StatelessWidget {
  final RideTrackingController controller;
  final Ride ride;

  const _RideActions({required this.controller, required this.ride});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (controller.isDriver) {
      final nextStatus = _nextDriverStatus(ride.status);
      if (nextStatus != null) {
        actions.add(
          ElevatedButton.icon(
            onPressed: controller.isUpdatingStatus
                ? null
                : () => controller.updateStatus(nextStatus),
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(_driverActionLabel(nextStatus)),
          ),
        );
      }
    }

    if (ride.hasDriver && !ride.status.isTerminal) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _openRideConversation(context),
          icon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('Message'),
        ),
      );
    }

    if (!ride.status.isTerminal) {
      actions.add(
        OutlinedButton.icon(
          onPressed: controller.isUpdatingStatus ? null : controller.cancelRide,
          icon: const Icon(Icons.cancel_rounded),
          label: const Text('Cancel'),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (actions.length > 2) {
      return Column(
        children: actions
            .asMap()
            .entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 10),
                child: SizedBox(width: double.infinity, child: entry.value),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: actions
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 10),
                child: entry.value,
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openRideConversation(BuildContext context) async {
    await openRideChat(
      context: context,
      ride: ride,
      currentUserId: controller.userId,
      currentUserRole: controller.isDriver ? 'driver' : 'passenger',
    );
  }

  RideStatus? _nextDriverStatus(RideStatus status) {
    return switch (status) {
      RideStatus.accepted => RideStatus.driverArriving,
      RideStatus.driverArriving => RideStatus.arrived,
      RideStatus.arrived => RideStatus.inProgress,
      RideStatus.inProgress => RideStatus.completed,
      _ => null,
    };
  }

  String _driverActionLabel(RideStatus status) {
    return switch (status) {
      RideStatus.driverArriving => 'Head to Pickup',
      RideStatus.arrived => 'Mark Arrived',
      RideStatus.inProgress => 'Start Trip',
      RideStatus.completed => 'Complete',
      _ => 'Update',
    };
  }
}
