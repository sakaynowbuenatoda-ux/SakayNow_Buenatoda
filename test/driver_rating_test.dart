import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/driver_rating.dart';

void main() {
  group('DriverRating', () {
    test('weighted score protects experienced highly rated drivers', () {
      final newPerfectDriver = DriverRating.weightedScore(
        ratingTotal: 5,
        reviewCount: 1,
      );
      final experiencedDriver = DriverRating.weightedScore(
        ratingTotal: 230,
        reviewCount: 50,
      );

      expect(experiencedDriver, greaterThan(newPerfectDriver));
    });

    test('uses numeric badges for ranked top drivers', () {
      expect(
        DriverRating.badgeLabel(reviewCount: 50, averageRating: 4.8, rank: 7),
        '#7',
      );
    });

    test('uses trust badges for unranked drivers', () {
      expect(
        DriverRating.badgeLabel(reviewCount: 2, averageRating: 5),
        'New Driver',
      );
      expect(
        DriverRating.badgeLabel(reviewCount: 8, averageRating: 4.8),
        'Rising Driver',
      );
      expect(
        DriverRating.badgeLabel(reviewCount: 55, averageRating: 4.5),
        'Highly Reviewed',
      );
    });
  });
}
