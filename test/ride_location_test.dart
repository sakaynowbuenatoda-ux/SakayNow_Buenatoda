import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/ride_location.dart';

void main() {
  group('RideLocation public display labels', () {
    test('keeps passenger quick destination label in passenger display', () {
      const location = RideLocation(
        address: 'Sweetland Health Center',
        name: 'College',
        latitude: 10.083,
        longitude: 124.178,
      );

      expect(location.displayLabel, 'College');
    });

    test('uses saved address instead of quick destination label publicly', () {
      const location = RideLocation(
        address: 'Sweetland Health Center',
        name: 'College',
        latitude: 10.083,
        longitude: 124.178,
      );

      expect(location.publicDisplayLabel, 'Sweetland Health Center');
    });

    test('uses Google place name publicly when a place id exists', () {
      const location = RideLocation(
        address: 'Buenavista, Bohol',
        name: 'Sweetland Barangay Hall',
        placeId: 'google-place-1',
        latitude: 10.083,
        longitude: 124.178,
      );

      expect(location.publicDisplayLabel, 'Sweetland Barangay Hall');
    });

    test('uses Google place id publicly when the place name is missing', () {
      const location = RideLocation(
        address: 'Buenavista, Bohol',
        placeId: 'google-place-1',
        latitude: 10.083,
        longitude: 124.178,
      );

      expect(location.publicDisplayLabel, 'google-place-1');
    });

    test('falls back to coordinates when only a shortcut label is stored', () {
      const location = RideLocation(
        address: 'College',
        name: 'College',
        latitude: 10.083,
        longitude: 124.178,
      );

      expect(location.publicDisplayLabel, '10.08300, 124.17800');
    });
  });
}
