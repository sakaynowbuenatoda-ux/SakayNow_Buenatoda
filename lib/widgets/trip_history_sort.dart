import 'package:flutter/material.dart';

import '../models/ride.dart';
import 'passenger_widgets/passenger_ui.dart';

enum TripHistorySortOption { newest, oldest, highestFare, lowestFare }

extension TripHistorySortOptionDetails on TripHistorySortOption {
  String get label => switch (this) {
    TripHistorySortOption.newest => 'Newest first',
    TripHistorySortOption.oldest => 'Oldest first',
    TripHistorySortOption.highestFare => 'Highest fare',
    TripHistorySortOption.lowestFare => 'Lowest fare',
  };

  String get helperText => switch (this) {
    TripHistorySortOption.newest => 'Show your latest trips at the top.',
    TripHistorySortOption.oldest => 'Show your earliest trips at the top.',
    TripHistorySortOption.highestFare =>
      'Show the most expensive trips at the top.',
    TripHistorySortOption.lowestFare =>
      'Show the least expensive trips at the top.',
  };
}

List<T> sortTripHistory<T>({
  required Iterable<T> trips,
  required Ride Function(T trip) rideOf,
  required TripHistorySortOption option,
}) {
  final sortedTrips = trips.toList(growable: false);
  sortedTrips.sort((a, b) {
    final aRide = rideOf(a);
    final bRide = rideOf(b);
    final comparison = switch (option) {
      TripHistorySortOption.newest => _compareDates(bRide, aRide),
      TripHistorySortOption.oldest => _compareDates(aRide, bRide),
      TripHistorySortOption.highestFare => _compareFares(
        aRide,
        bRide,
        descending: true,
      ),
      TripHistorySortOption.lowestFare => _compareFares(
        aRide,
        bRide,
        descending: false,
      ),
    };

    if (comparison != 0) {
      return comparison;
    }

    // Keep equal values deterministic and favor the most recent trip.
    final dateComparison = _compareDates(bRide, aRide);
    return dateComparison != 0
        ? dateComparison
        : aRide.bookingId.compareTo(bRide.bookingId);
  });
  return sortedTrips;
}

int _compareDates(Ride a, Ride b) => _historyDate(a).compareTo(_historyDate(b));

DateTime _historyDate(Ride ride) =>
    ride.historyDate ?? DateTime.fromMillisecondsSinceEpoch(0);

int _compareFares(Ride a, Ride b, {required bool descending}) {
  final aFare = a.fareAmount ?? a.grossFare;
  final bFare = b.fareAmount ?? b.grossFare;

  // Trips whose fare was never finalized stay below trips with known fares.
  if (aFare == null) {
    return bFare == null ? 0 : 1;
  }
  if (bFare == null) {
    return -1;
  }

  return descending ? bFare.compareTo(aFare) : aFare.compareTo(bFare);
}

class TripHistorySortControl extends StatelessWidget {
  final TripHistorySortOption value;
  final ValueChanged<TripHistorySortOption> onChanged;

  const TripHistorySortControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sort_rounded,
              color: PassengerUi.accentBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sort trips',
                  style: PassengerUi.valueText.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value.helperText,
                  style: PassengerUi.bodyText.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<TripHistorySortOption>(
              key: const ValueKey<String>('trip-history-sort'),
              value: value,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.expand_more_rounded),
              style: PassengerUi.valueText.copyWith(fontSize: 12.5),
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
              items: TripHistorySortOption.values
                  .map(
                    (option) => DropdownMenuItem<TripHistorySortOption>(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}
