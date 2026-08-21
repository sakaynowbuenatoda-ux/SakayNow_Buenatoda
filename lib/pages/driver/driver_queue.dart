import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride.dart';
import '../../services/booking_action_cooldown_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/action_cooldown_notice.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../rides/ride_monitoring_page.dart';
import 'widgets/driver_ride_request_card.dart';

class DriverQueuePage extends StatefulWidget {
  final String driverId;
  final bool isVerified;
  final bool canReceiveBookings;
  final bool isActive;

  const DriverQueuePage({
    super.key,
    required this.driverId,
    required this.isVerified,
    required this.canReceiveBookings,
    required this.isActive,
  });

  @override
  State<DriverQueuePage> createState() => _DriverQueuePageState();
}

class _DriverQueuePageState extends State<DriverQueuePage> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final BookingActionCooldownService _cooldownService =
      BookingActionCooldownService.instance;
  String? _acceptingBookingId;
  String? _decliningBookingId;

  @override
  void initState() {
    super.initState();
    _cooldownService.addListener(_handleCooldownChanged);
    unawaited(
      _cooldownService.loadForUser(
        userId: widget.driverId,
        targets: const <BookingActionCooldownTarget>[
          BookingActionCooldownTarget.driverAccept,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cooldownService.removeListener(_handleCooldownChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        title: Text('Queue', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!widget.isVerified)
              const PassengerEmptyState(
                icon: Icons.verified_user_outlined,
                title: 'Pending verification',
                description:
                    'Admin verification is required before accepting passenger bookings.',
              )
            else if (!widget.canReceiveBookings)
              const PassengerEmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Documents expired',
                description:
                    'Your account remains verified. Submit a current Driver\'s License or OR/CR before opening the booking queue.',
              )
            else if (!widget.isActive)
              const PassengerEmptyState(
                icon: Icons.power_settings_new_rounded,
                title: 'Go active to open queue',
                description:
                    'Turn on driver availability when you are ready to receive nearby passenger requests.',
              )
            else
              StreamBuilder<List<Ride>>(
                stream: _rideTrackingService.watchOpenBookings(
                  driverId: widget.driverId,
                  includeDeclined: true,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return PassengerEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to load bookings',
                      description:
                          'Booking requests could not be loaded. Please try again.',
                    );
                  }

                  final rides = snapshot.data ?? <Ride>[];
                  final acceptCooldownRemaining = _acceptCooldownRemaining;
                  if (rides.isEmpty) {
                    return const PassengerEmptyState(
                      icon: Icons.route_rounded,
                      title: 'No active requests',
                      description:
                          'New passenger bookings will appear here in real time.',
                    );
                  }

                  return Column(
                    children: <Widget>[
                      if (acceptCooldownRemaining > Duration.zero) ...<Widget>[
                        ActionCooldownNotice(
                          message:
                              'You can accept another request in ${BookingActionCooldownService.formatRemaining(acceptCooldownRemaining)}.',
                        ),
                        const SizedBox(height: 12),
                      ],
                      ...rides.asMap().entries.map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == rides.length - 1 ? 0 : 12,
                          ),
                          child: DriverRideRequestCard(
                            ride: entry.value,
                            driverId: widget.driverId,
                            isAccepting:
                                _acceptingBookingId == entry.value.bookingId,
                            isDeclining:
                                _decliningBookingId == entry.value.bookingId,
                            acceptCooldownRemaining: acceptCooldownRemaining,
                            canAcceptDeclined: true,
                            rideTrackingService: _rideTrackingService,
                            onAccept: () => _acceptRide(entry.value),
                            onDecline: () => _declineRide(entry.value),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Duration get _acceptCooldownRemaining {
    return _cooldownService.remainingFor(
      userId: widget.driverId,
      target: BookingActionCooldownTarget.driverAccept,
    );
  }

  void _handleCooldownChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _acceptRide(Ride ride) async {
    if (!widget.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin verification is required before accepting bookings.',
          ),
        ),
      );
      return;
    }
    if (!widget.canReceiveBookings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account remains verified, but current driver documents are required before accepting bookings.',
          ),
        ),
      );
      return;
    }

    final acceptCooldownRemaining = _acceptCooldownRemaining;
    if (acceptCooldownRemaining > Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait ${BookingActionCooldownService.formatRemaining(acceptCooldownRemaining)} before accepting another request.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _acceptingBookingId = ride.bookingId;
    });

    try {
      await _rideTrackingService.acceptBooking(
        bookingId: ride.bookingId,
        driverId: widget.driverId,
        allowDeclined: ride.declinedDriverIds.contains(widget.driverId),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideMonitoringPage(
            bookingId: ride.bookingId,
            userId: widget.driverId,
            viewerRole: RideViewerRole.driver,
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
              fallback: 'Unable to accept this request. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _acceptingBookingId = null;
        });
      }
    }
  }

  Future<void> _declineRide(Ride ride) async {
    if (!widget.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin verification is required before declining bookings.',
          ),
        ),
      );
      return;
    }
    if (!widget.canReceiveBookings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account remains verified, but current driver documents are required before managing booking requests.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _decliningBookingId = ride.bookingId;
    });

    try {
      await _rideTrackingService.declineBooking(
        bookingId: ride.bookingId,
        driverId: widget.driverId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request declined and kept open for other drivers.'),
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
              fallback: 'Unable to decline this request. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _decliningBookingId = null;
        });
      }
    }
  }
}
