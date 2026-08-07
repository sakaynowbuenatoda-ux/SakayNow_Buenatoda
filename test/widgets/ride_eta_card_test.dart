import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/ride_status.dart';
import 'package:sakaynow_buenatoda/widgets/rides/ride_eta_card.dart';

import '../support/ride_fixture.dart';

void main() {
  testWidgets('updates pickup copy when driver status changes to arrived', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideEtaCard(
            ride: buildRideFixture(status: RideStatus.driverArriving),
          ),
        ),
      ),
    );

    expect(find.text('Driver on the way'), findsOneWidget);
    expect(find.text('Pickup ETA'), findsOneWidget);
    expect(find.text('5 mins'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideEtaCard(ride: buildRideFixture(status: RideStatus.arrived)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Driver has arrived'), findsOneWidget);
    expect(find.text('Pickup status'), findsOneWidget);
    expect(find.text('Arrived'), findsOneWidget);
    expect(find.text('Pickup ETA'), findsNothing);
  });

  testWidgets('shows destination ETA and remaining distance in progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideEtaCard(
            ride: buildRideFixture(status: RideStatus.inProgress),
          ),
        ),
      ),
    );

    expect(find.text('Heading to destination'), findsOneWidget);
    expect(find.text('Destination ETA'), findsOneWidget);
    expect(find.text('8 mins'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
  });
}
