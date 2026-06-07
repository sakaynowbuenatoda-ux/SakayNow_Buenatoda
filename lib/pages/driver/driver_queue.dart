import 'package:flutter/material.dart';

import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../rides/ride_monitoring_page.dart';
import 'widgets/driver_ride_request_card.dart';

class DriverQueuePage extends StatefulWidget {
  final String driverId;
  final bool isVerified;

  const DriverQueuePage({
    super.key,
    required this.driverId,
    required this.isVerified,
  });

  @override
  State<DriverQueuePage> createState() => _DriverQueuePageState();
}

class _DriverQueuePageState extends State<DriverQueuePage> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  String? _acceptingBookingId;
  String? _decliningBookingId;

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Queue',
            subtitle:
                'Accept nearby passenger requests and monitor live ride progress.',
            icon: Icons.list_alt_rounded,
            accentColor: PassengerUi.highlightAmber,
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Ride>>(
            stream: _rideTrackingService.watchOpenBookings(
              driverId: widget.driverId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return PassengerEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load bookings',
                  description: snapshot.error.toString(),
                );
              }

              final rides = snapshot.data ?? <Ride>[];
              if (rides.isEmpty) {
                return const PassengerEmptyState(
                  icon: Icons.route_rounded,
                  title: 'No active requests',
                  description:
                      'New passenger bookings will appear here in real time.',
                );
              }

              return Column(
                children: rides
                    .asMap()
                    .entries
                    .map(
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
                          rideTrackingService: _rideTrackingService,
                          onAccept: () => _acceptRide(entry.value),
                          onDecline: () => _declineRide(entry.value),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
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

    setState(() {
      _acceptingBookingId = ride.bookingId;
    });

    try {
      await _rideTrackingService.acceptBooking(
        bookingId: ride.bookingId,
        driverId: widget.driverId,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _decliningBookingId = null;
        });
      }
    }
  }
}
