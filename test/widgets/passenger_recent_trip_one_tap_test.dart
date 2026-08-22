import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/controllers/quick_destinations_controller.dart';
import 'package:sakaynow_buenatoda/models/ride_status.dart';
import 'package:sakaynow_buenatoda/pages/driver/driver_home.dart';
import 'package:sakaynow_buenatoda/services/ride_tracking_service.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_recent_trips_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ride_fixture.dart';

void main() {
  testWidgets('a recent trip can be added to one-tap booking', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = QuickDestinationsController(
      userId: 'passenger-1',
      firestore: FakeFirebaseFirestore(),
    );
    addTearDown(controller.dispose);
    final trip = PassengerRecentTrip(
      ride: buildRideFixture(status: RideStatus.completed),
      driver: const DriverReviewProfile(
        driverId: 'driver-1',
        fullName: 'Juan Dela Cruz',
        isVerified: true,
        isActive: true,
        isBanned: false,
        profileImageUrl: null,
        averageRating: 4.8,
        reviewCount: 10,
        weightedRating: 4.5,
        ratingRank: 2,
        ratingBadge: 'Top rated',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: PassengerTripCard(
                  trip: trip,
                  passengerId: 'passenger-1',
                  quickDestinationsController: controller,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Add to one-tap'), findsNothing);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
    expect(
      tester.getSize(find.byType(PassengerTripCard)).height,
      lessThan(180),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('save-trip-to-one-tap-booking-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.destinations, hasLength(1));
    expect(controller.destinations.single.label, 'New Poblacion');
    expect(find.text('Saved to one-tap'), findsNothing);
    expect(find.byIcon(Icons.bookmark_added_rounded), findsOneWidget);
    expect(
      find.text('New Poblacion added to One-tap booking.'),
      findsOneWidget,
    );
  });

  testWidgets('driver recent trip card stays compact on a narrow layout', (
    tester,
  ) async {
    final trip = DriverRecentTrip(
      ride: buildRideFixture(
        status: RideStatus.completed,
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      passenger: const PassengerReviewProfile(
        userId: 'passenger-1',
        fullName: 'Juan Smith',
        passengerType: 'student',
        isVerified: true,
        profileImageUrl: null,
        averageRating: 4.9,
        reviewCount: 8,
      ),
    );
    final service = RideTrackingService(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: DriverRecentTripCard(
                  trip: trip,
                  driverId: 'driver-1',
                  rideTrackingService: service,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(DriverRecentTripCard)).height,
      lessThan(170),
    );
    expect(
      find.byKey(const ValueKey<String>('driver-trip-report-booking-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('driver-trip-review-booking-1')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.map_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
