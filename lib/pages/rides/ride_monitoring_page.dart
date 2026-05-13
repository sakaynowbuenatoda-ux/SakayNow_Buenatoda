import 'package:flutter/material.dart';

import '../../controllers/ride_tracking_controller.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = RideTrackingController(
      bookingId: widget.bookingId,
      userId: widget.userId,
      viewerRole: widget.viewerRole,
    );
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
