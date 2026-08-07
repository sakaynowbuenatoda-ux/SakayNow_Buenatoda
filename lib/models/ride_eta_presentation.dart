import 'ride.dart';
import 'ride_status.dart';

class RideEtaPresentation {
  final String title;
  final String description;
  final String etaLabel;
  final String etaValue;
  final String distanceLabel;
  final String distanceValue;

  const RideEtaPresentation({
    required this.title,
    required this.description,
    required this.etaLabel,
    required this.etaValue,
    required this.distanceLabel,
    required this.distanceValue,
  });

  factory RideEtaPresentation.forRide(Ride ride) {
    return switch (ride.status) {
      RideStatus.searching => RideEtaPresentation(
        title: 'Finding a driver',
        description: 'Trip estimate while a driver is being found.',
        etaLabel: 'Estimated trip time',
        etaValue: ride.etaLabel,
        distanceLabel: 'Trip distance',
        distanceValue: ride.distanceLabel,
      ),
      RideStatus.accepted => RideEtaPresentation(
        title: 'Driver accepted',
        description: 'Live estimate to your pickup point.',
        etaLabel: 'Pickup ETA',
        etaValue: ride.etaLabel,
        distanceLabel: 'To pickup',
        distanceValue: ride.distanceLabel,
      ),
      RideStatus.driverArriving => RideEtaPresentation(
        title: 'Driver on the way',
        description: 'Live estimate to your pickup point.',
        etaLabel: 'Pickup ETA',
        etaValue: ride.etaLabel,
        distanceLabel: 'To pickup',
        distanceValue: ride.distanceLabel,
      ),
      RideStatus.arrived => const RideEtaPresentation(
        title: 'Driver has arrived',
        description: 'Meet your driver at the pickup point.',
        etaLabel: 'Pickup status',
        etaValue: 'Arrived',
        distanceLabel: 'Driver location',
        distanceValue: 'At pickup',
      ),
      RideStatus.inProgress => RideEtaPresentation(
        title: 'Heading to destination',
        description: 'Live estimate to your drop-off point.',
        etaLabel: 'Destination ETA',
        etaValue: ride.etaLabel,
        distanceLabel: 'Remaining',
        distanceValue: ride.distanceLabel,
      ),
      RideStatus.completed => RideEtaPresentation(
        title: 'Trip completed',
        description: 'You have reached your destination.',
        etaLabel: 'Trip status',
        etaValue: ride.status.label,
        distanceLabel: 'Trip distance',
        distanceValue: ride.distanceLabel,
      ),
      RideStatus.cancelled => RideEtaPresentation(
        title: 'Trip cancelled',
        description: 'This trip is no longer active.',
        etaLabel: 'Trip status',
        etaValue: ride.status.label,
        distanceLabel: 'Trip distance',
        distanceValue: ride.distanceLabel,
      ),
    };
  }
}
