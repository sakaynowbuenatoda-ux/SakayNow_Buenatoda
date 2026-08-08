class RideEarningsBreakdown {
  final int grossFare;
  final double commissionRate;
  final int commissionAmount;
  final int driverNetEarnings;

  const RideEarningsBreakdown({
    required this.grossFare,
    required this.commissionRate,
    required this.commissionAmount,
    required this.driverNetEarnings,
  });

  factory RideEarningsBreakdown.calculate({
    required int grossFare,
    required double commissionRate,
  }) {
    final normalizedGrossFare = grossFare < 0 ? 0 : grossFare;
    final normalizedRate = commissionRate.clamp(0.0, 1.0).toDouble();
    final commission = (normalizedGrossFare * normalizedRate).round().clamp(
      0,
      normalizedGrossFare,
    );

    return RideEarningsBreakdown(
      grossFare: normalizedGrossFare,
      commissionRate: normalizedRate,
      commissionAmount: commission,
      driverNetEarnings: normalizedGrossFare - commission,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'gross_fare': grossFare,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'driver_net_earnings': driverNetEarnings,
    };
  }
}
