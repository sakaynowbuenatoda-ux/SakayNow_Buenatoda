import 'package:flutter/material.dart';

import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../rides/ride_monitoring_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Booking Queue',
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
                        child: _DriverRideRequestCard(
                          ride: entry.value,
                          isAccepting:
                              _acceptingBookingId == entry.value.bookingId,
                          onAccept: () => _acceptRide(entry.value),
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
}

class _DriverRideRequestCard extends StatelessWidget {
  final Ride ride;
  final bool isAccepting;
  final VoidCallback onAccept;

  const _DriverRideRequestCard({
    required this.ride,
    required this.isAccepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Passenger request', style: PassengerUi.cardTitle),
              ),
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
            value: ride.pickupLocation.address,
          ),
          const SizedBox(height: 10),
          _RouteLine(
            icon: Icons.location_on_rounded,
            iconColor: PassengerUi.primary,
            label: 'Drop-off',
            value: ride.dropoffLocation.address,
          ),
          const SizedBox(height: 14),
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
                  style: PassengerUi.bodyText,
                ),
              ),
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
                    : const Icon(Icons.check_rounded),
                label: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: iconColor, size: 20),
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
