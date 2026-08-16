import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/ride.dart';
import 'package:sakaynow_buenatoda/widgets/trip_history_sort.dart';

import '../support/ride_fixture.dart';

void main() {
  group('sortTripHistory', () {
    final olderCheapRide = buildRideFixture(
      updatedAt: DateTime(2025, 1, 1),
      fareAmount: 40,
    );
    final middleExpensiveRide = buildRideFixture(
      updatedAt: DateTime(2025, 2, 1),
      fareAmount: 120,
    );
    final newerRide = buildRideFixture(
      updatedAt: DateTime(2025, 3, 1),
      fareAmount: 80,
    );
    final rides = <Ride>[middleExpensiveRide, olderCheapRide, newerRide];

    test('supports newest and oldest ordering', () {
      expect(_sort(rides, TripHistorySortOption.newest), <Ride>[
        newerRide,
        middleExpensiveRide,
        olderCheapRide,
      ]);
      expect(_sort(rides, TripHistorySortOption.oldest), <Ride>[
        olderCheapRide,
        middleExpensiveRide,
        newerRide,
      ]);
    });

    test('supports highest and lowest fare ordering', () {
      expect(_sort(rides, TripHistorySortOption.highestFare), <Ride>[
        middleExpensiveRide,
        newerRide,
        olderCheapRide,
      ]);
      expect(_sort(rides, TripHistorySortOption.lowestFare), <Ride>[
        olderCheapRide,
        newerRide,
        middleExpensiveRide,
      ]);
    });
  });

  testWidgets('sort control explains and reports the selected option', (
    tester,
  ) async {
    TripHistorySortOption? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripHistorySortControl(
            value: TripHistorySortOption.newest,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Sort trips'), findsOneWidget);
    expect(find.text('Show your latest trips at the top.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('trip-history-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lowest fare').last);
    await tester.pumpAndSettle();

    expect(selected, TripHistorySortOption.lowestFare);
  });
}

List<Ride> _sort(List<Ride> rides, TripHistorySortOption option) {
  return sortTripHistory<Ride>(
    trips: rides,
    rideOf: (ride) => ride,
    option: option,
  );
}
