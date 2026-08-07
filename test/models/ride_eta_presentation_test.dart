import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/ride_eta_presentation.dart';
import 'package:sakaynow_buenatoda/models/ride_status.dart';

import '../support/ride_fixture.dart';

void main() {
  group('RideEtaPresentation', () {
    test('shows pickup ETA after a driver accepts', () {
      final ride = buildRideFixture(status: RideStatus.accepted);
      final presentation = RideEtaPresentation.forRide(ride);

      expect(presentation.title, 'Driver accepted');
      expect(presentation.etaLabel, 'Pickup ETA');
      expect(presentation.etaValue, '5 mins');
      expect(presentation.distanceLabel, 'To pickup');
      expect(ride.status.passengerMonitoringSubtitle, contains('pickup ETA'));
    });

    test('makes driver arrival explicit instead of showing a stale ETA', () {
      final ride = buildRideFixture(
        status: RideStatus.arrived,
        driverToPickupDurationSeconds: 60,
      );
      final presentation = RideEtaPresentation.forRide(ride);

      expect(ride.etaLabel, 'Arrived');
      expect(presentation.title, 'Driver has arrived');
      expect(presentation.etaLabel, 'Pickup status');
      expect(presentation.etaValue, 'Arrived');
      expect(presentation.distanceValue, 'At pickup');
    });

    test('switches to remaining destination ETA while in progress', () {
      final ride = buildRideFixture(
        status: RideStatus.inProgress,
        remainingRideDurationSeconds: 241,
      );
      final presentation = RideEtaPresentation.forRide(ride);

      expect(presentation.title, 'Heading to destination');
      expect(presentation.etaLabel, 'Destination ETA');
      expect(presentation.etaValue, '5 mins');
      expect(presentation.distanceLabel, 'Remaining');
      expect(
        ride.status.passengerMonitoringSubtitle,
        contains('destination ETA'),
      );
    });
  });
}
