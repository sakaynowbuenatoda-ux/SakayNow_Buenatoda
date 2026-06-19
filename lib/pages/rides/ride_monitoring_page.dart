import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/ride_tracking_controller.dart';
import '../../core/preferences/app_preferences_controller.dart';
import '../../models/passenger_payment_method.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../pages/messages/ride_chat_navigation.dart';
import '../../pages/profile/passenger_profile.dart';
import '../../services/booking_action_cooldown_service.dart';
import '../../services/payment_method_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../services/xendit_checkout_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/maps/map_type_toggle.dart';
import '../../widgets/maps/sakay_google_map.dart';
import '../../widgets/maps/map_text_styles.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/passenger_widgets/ride_status_strip.dart';
import '../../widgets/reviews/review_dialogs.dart';

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
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final PaymentMethodService _paymentMethodService = PaymentMethodService();
  final XenditCheckoutService _xenditCheckoutService = XenditCheckoutService();
  static const Duration _terminalStatusDialogDuration = Duration(seconds: 10);

  RideStatus? _shownTerminalStatus;
  Ride? _terminalStatusRide;
  OverlayEntry? _terminalStatusOverlay;
  Timer? _terminalStatusTimer;
  final Set<String> _promptedReviewBookingIds = <String>{};
  bool _isOpeningCheckout = false;
  bool _isChangingPaymentMethod = false;

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
    _removeTerminalStatusDialog();
    _controller.removeListener(_handleRideUpdates);
    _controller.dispose();
    super.dispose();
  }

  void _handleRideUpdates() {
    final ride = _controller.ride;
    if (ride == null ||
        !ride.status.isTerminal ||
        _shownTerminalStatus == ride.status) {
      return;
    }

    _shownTerminalStatus = ride.status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showTerminalStatusDialog(ride);
    });
  }

  void _showTerminalStatusDialog(Ride ride) {
    _removeTerminalStatusDialog();
    _terminalStatusRide = ride;

    final entry = OverlayEntry(
      builder: (context) => _TerminalStatusOverlay(
        status: ride.status,
        onDismiss: () => _removeTerminalStatusDialog(showFollowUp: true),
      ),
    );

    _terminalStatusOverlay = entry;
    Overlay.of(context).insert(entry);
    _terminalStatusTimer = Timer(
      _terminalStatusDialogDuration,
      () => _removeTerminalStatusDialog(showFollowUp: true),
    );
  }

  void _removeTerminalStatusDialog({bool showFollowUp = false}) {
    final ride = _terminalStatusRide;
    _terminalStatusTimer?.cancel();
    _terminalStatusTimer = null;
    _terminalStatusOverlay?.remove();
    _terminalStatusOverlay = null;
    _terminalStatusRide = null;

    if (showFollowUp && ride != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPassengerDriverReviewPromptIfNeeded(ride);
        }
      });
    }
  }

  Future<void> _showPassengerDriverReviewPromptIfNeeded(Ride ride) async {
    if (widget.viewerRole != RideViewerRole.passenger ||
        !ride.canPassengerReviewDriver ||
        !_promptedReviewBookingIds.add(ride.bookingId)) {
      return;
    }

    final driverId = ride.driverId;
    if (driverId == null || driverId.trim().isEmpty) {
      return;
    }

    var driverName = 'your driver';
    try {
      final driver = await _rideTrackingService.loadDriverProfile(driverId);
      driverName = driver.fullName;
    } catch (_) {
      // The review can still be submitted because the booking holds the driver id.
    }

    if (!mounted) {
      return;
    }

    final draft = await showPassengerDriverReviewDialog(
      context,
      driverName: driverName,
    );
    if (draft == null || !mounted) {
      return;
    }

    try {
      await _rideTrackingService.savePassengerDriverReview(
        bookingId: ride.bookingId,
        passengerId: widget.userId,
        driverId: driverId,
        rating: draft.rating,
        comment: draft.comment,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver review saved.')));
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save review: $error')));
    }
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
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: AppPreferencesController.instance,
                                builder: (context, _) {
                                  return SakayGoogleMap(
                                    initialCameraTarget:
                                        _controller.initialCameraTarget,
                                    bounds: _controller.visibleBounds,
                                    markers: _controller.markers,
                                    polylines: _controller.polylines,
                                    circles: _controller.circles,
                                    mapType: AppPreferencesController
                                        .instance
                                        .googleMapType,
                                    myLocationEnabled: _controller.isDriver,
                                  );
                                },
                              ),
                            ),
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: MapTypeToggle(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RideStatusStripForRide(ride: ride),
                  const SizedBox(height: 16),
                  _RideEtaCard(ride: ride),
                  const SizedBox(height: 16),
                  _RideRouteCard(
                    ride: ride,
                    usePublicLocationLabels: _controller.isDriver,
                  ),
                  const SizedBox(height: 16),
                  _buildRidePaymentCard(ride),
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

  Widget _buildRidePaymentCard(Ride ride) {
    if (!_controller.isPassenger) {
      return _RidePaymentCard(
        ride: ride,
        canOpenCheckout: false,
        canChangePayment: false,
        isOpeningCheckout: _isOpeningCheckout,
        isChangingPayment: _isChangingPaymentMethod,
        onOpenCheckout: () => _openXenditCheckout(ride),
        onChangePayment: null,
      );
    }

    return StreamBuilder<List<PassengerPaymentMethod>>(
      stream: _paymentMethodService.watchPaymentMethods(widget.userId),
      builder: (context, snapshot) {
        final methods =
            snapshot.data ??
            <PassengerPaymentMethod>[
              PassengerPaymentMethod.cash(userId: widget.userId),
            ];

        return _RidePaymentCard(
          ride: ride,
          canOpenCheckout: true,
          canChangePayment: _canChangePaymentMethod(ride),
          isOpeningCheckout: _isOpeningCheckout,
          isChangingPayment: _isChangingPaymentMethod,
          onOpenCheckout: () => _openXenditCheckout(ride),
          onChangePayment: () => _showPaymentMethodPicker(ride, methods),
        );
      },
    );
  }

  bool _canChangePaymentMethod(Ride ride) {
    return !ride.status.isTerminal && !ride.isPaymentPaid;
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

  Future<void> _showPaymentMethodPicker(
    Ride ride,
    List<PassengerPaymentMethod> methods,
  ) async {
    final selected = await showModalBottomSheet<PassengerPaymentMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RidePaymentMethodPickerSheet(
        methods: methods,
        selectedMethodId: _currentPaymentMethodId(ride),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    final currentMethodId = _currentPaymentMethodId(ride);
    if (selected.id == currentMethodId) {
      return;
    }

    await _changePaymentMethod(ride, selected);
  }

  String _currentPaymentMethodId(Ride ride) {
    final paymentMethodId = ride.paymentMethodId?.trim();
    if (paymentMethodId != null && paymentMethodId.isNotEmpty) {
      return paymentMethodId;
    }

    final paymentMethod = ride.paymentMethod.trim().toLowerCase();
    return paymentMethod == 'cash'
        ? PassengerPaymentMethod.cashMethodId
        : paymentMethod;
  }

  Future<void> _changePaymentMethod(
    Ride ride,
    PassengerPaymentMethod paymentMethod,
  ) async {
    setState(() {
      _isChangingPaymentMethod = true;
    });

    try {
      await _rideTrackingService.updateBookingPaymentMethod(
        bookingId: ride.bookingId,
        passengerId: widget.userId,
        paymentMethod: paymentMethod,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentMethod.usesOnlineCheckout
                ? 'Payment method updated. Tap Pay now to open checkout.'
                : 'Payment method updated.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback:
                  'Payment method could not be changed. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPaymentMethod = false;
        });
      }
    }
  }

  Future<void> _openXenditCheckout(Ride ride) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Open Xendit Checkout?',
      message: 'You will be redirected to the current payment gateway.',
      confirmLabel: 'OK',
      cancelLabel: 'Cancel',
      icon: Icons.account_balance_wallet_rounded,
      confirmColor: PassengerUi.accentBlue,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isOpeningCheckout = true);
    try {
      var checkoutUrl = ride.checkoutUrl?.trim();
      if (checkoutUrl == null ||
          checkoutUrl.isEmpty ||
          ride.paymentStatus == 'checkout_failed') {
        final paymentMethodType = ride.xenditPaymentMethodType;
        if (paymentMethodType == null || paymentMethodType.trim().isEmpty) {
          throw Exception('Xendit payment method is not ready yet.');
        }

        final session = await _xenditCheckoutService
            .createCheckoutSessionForPaymentType(
              bookingId: ride.bookingId,
              paymentMethodType: paymentMethodType,
              paymentMethodId: ride.paymentMethodId,
            );
        checkoutUrl = session.checkoutUrl;
      }

      await _xenditCheckoutService.openCheckoutUrl(checkoutUrl);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback:
                  'Online checkout could not open. Please try again or pay with cash.',
            ),
          ),
        ),
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
  final bool usePublicLocationLabels;

  const _RideRouteCard({
    required this.ride,
    required this.usePublicLocationLabels,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        children: <Widget>[
          _LocationRow(
            icon: Icons.my_location_rounded,
            iconColor: PassengerUi.secondary,
            label: 'Pickup',
            value: usePublicLocationLabels
                ? ride.pickupLocation.publicDisplayLabel
                : ride.pickupLocation.displayLabel,
          ),
          const SizedBox(height: 12),
          _LocationRow(
            icon: Icons.location_on_rounded,
            iconColor: PassengerUi.primary,
            label: 'Drop-off',
            value: usePublicLocationLabels
                ? ride.dropoffLocation.publicDisplayLabel
                : ride.dropoffLocation.displayLabel,
          ),
        ],
      ),
    );
  }
}

class _RidePaymentCard extends StatelessWidget {
  final Ride ride;
  final bool canOpenCheckout;
  final bool canChangePayment;
  final bool isOpeningCheckout;
  final bool isChangingPayment;
  final VoidCallback onOpenCheckout;
  final VoidCallback? onChangePayment;

  const _RidePaymentCard({
    required this.ride,
    required this.canOpenCheckout,
    required this.canChangePayment,
    required this.isOpeningCheckout,
    required this.isChangingPayment,
    required this.onOpenCheckout,
    required this.onChangePayment,
  });

  @override
  Widget build(BuildContext context) {
    final showCheckoutButton =
        canOpenCheckout && ride.usesOnlineCheckout && !ride.isPaymentPaid;

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              if (canChangePayment)
                TextButton.icon(
                  onPressed: isChangingPayment || isOpeningCheckout
                      ? null
                      : onChangePayment,
                  icon: isChangingPayment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Change'),
                ),
              if (showCheckoutButton) ...<Widget>[
                TextButton.icon(
                  onPressed: isOpeningCheckout || isChangingPayment
                      ? null
                      : onOpenCheckout,
                  icon: isOpeningCheckout
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(isOpeningCheckout ? 'Opening...' : 'Pay now'),
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

class _RidePaymentMethodPickerSheet extends StatelessWidget {
  final List<PassengerPaymentMethod> methods;
  final String selectedMethodId;

  const _RidePaymentMethodPickerSheet({
    required this.methods,
    required this.selectedMethodId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        decoration: BoxDecoration(
          color: PassengerUi.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PassengerUi.border),
          boxShadow: PassengerUi.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Choose Payment', style: MapTextStyles.title),
            const SizedBox(height: 12),
            for (final method in methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: method.type.accentColor.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(method.type.icon, color: method.type.accentColor),
                ),
                title: Text(method.displayLabel, style: MapTextStyles.value),
                subtitle: Text(
                  method.accountLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.body.copyWith(fontSize: 12),
                ),
                trailing: method.id == selectedMethodId
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: PassengerUi.successText,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(method),
              ),
          ],
        ),
      ),
    );
  }
}

class _TerminalStatusOverlay extends StatelessWidget {
  final RideStatus status;
  final VoidCallback onDismiss;

  const _TerminalStatusOverlay({required this.status, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.24),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(scale: value, child: child),
                  );
                },
                child: _TerminalStatusDialog(status: status),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalStatusDialog extends StatelessWidget {
  final RideStatus status;

  const _TerminalStatusDialog({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == RideStatus.completed;
    final accentColor = isCompleted
        ? PassengerUi.successText
        : PassengerUi.primary;
    final accentBackground = isCompleted
        ? PassengerUi.successBackground
        : PassengerUi.dangerSoft;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PassengerUi.border),
            boxShadow: PassengerUi.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accentBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_icon, color: accentColor, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: PassengerUi.sectionTitle.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (status) {
      RideStatus.completed => Icons.check_circle_rounded,
      RideStatus.cancelled => Icons.cancel_rounded,
      _ => Icons.info_rounded,
    };
  }

  String get _title {
    return switch (status) {
      RideStatus.completed => 'Booking Completed',
      RideStatus.cancelled => 'Booking Cancelled',
      _ => 'Booking Updated',
    };
  }

  String get _message {
    return switch (status) {
      RideStatus.completed => 'This ride has been marked as completed.',
      RideStatus.cancelled => 'This ride request has been cancelled.',
      _ => 'The booking status has been updated.',
    };
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
        final isAwaitingCashlessPayment =
            nextStatus == RideStatus.completed &&
            ride.usesOnlineCheckout &&
            !ride.isPaymentPaid;
        actions.add(
          ElevatedButton.icon(
            onPressed: controller.isUpdatingStatus || isAwaitingCashlessPayment
                ? null
                : () => controller.updateStatus(nextStatus),
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(
              isAwaitingCashlessPayment
                  ? 'Awaiting Payment'
                  : _driverActionLabel(nextStatus),
            ),
          ),
        );
      }

      if (ride.passengerId.trim().isNotEmpty) {
        actions.add(
          OutlinedButton.icon(
            onPressed: () => _openPassengerProfile(context),
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Passenger'),
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
          onPressed: controller.isUpdatingStatus
              ? null
              : () => _confirmCancelRide(context),
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

  void _openPassengerProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassengerProfilePage(
          passengerId: ride.passengerId,
          driverId: controller.userId,
          bookingId: ride.bookingId,
        ),
      ),
    );
  }

  Future<void> _confirmCancelRide(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Cancel Booking?',
      message:
          'This will cancel the active booking and notify the ${controller.isDriver ? 'passenger' : 'driver'}.',
      confirmLabel: 'Cancel Booking',
      icon: Icons.cancel_rounded,
      confirmColor: PassengerUi.primary,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    await controller.cancelRide();
    if (!context.mounted || controller.errorMessage != null) {
      return;
    }

    final target = controller.isDriver
        ? BookingActionCooldownTarget.driverAccept
        : BookingActionCooldownTarget.passengerBooking;
    final cooldown = await BookingActionCooldownService.instance
        .startAfterCancellation(userId: controller.userId, target: target);

    if (!context.mounted) {
      return;
    }

    final actionLabel = controller.isDriver
        ? 'accept another request'
        : 'request another ride';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ride cancelled. You can $actionLabel in ${BookingActionCooldownService.formatRemaining(cooldown)}.',
        ),
      ),
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
