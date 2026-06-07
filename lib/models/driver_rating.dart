class DriverRating {
  const DriverRating._();

  static const double priorAverage = 4.0;
  static const int minimumReviews = 20;
  static const int leaderboardLimit = 20;
  static const double risingDriverAverage = 4.7;
  static const int closeDistanceTieMeters = 150;

  static double weightedScore({
    required int ratingTotal,
    required int reviewCount,
  }) {
    if (reviewCount <= 0) {
      return 0;
    }

    return (ratingTotal + (priorAverage * minimumReviews)) /
        (reviewCount + minimumReviews);
  }

  static String badgeLabel({
    required int reviewCount,
    required double averageRating,
    int? rank,
  }) {
    if (rank != null && rank >= 1 && rank <= leaderboardLimit) {
      return '#$rank';
    }

    if (reviewCount < 5) {
      return 'New Driver';
    }

    if (reviewCount < minimumReviews && averageRating >= risingDriverAverage) {
      return 'Rising Driver';
    }

    if (reviewCount >= 50) {
      return 'Highly Reviewed';
    }

    return '';
  }
}
