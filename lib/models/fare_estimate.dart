import 'package:cloud_firestore/cloud_firestore.dart';

class FareEstimate {
  static const double studentDiscountRate = 0.15;
  static const String regularPassengerDiscountCode = 'regular_passenger';
  static const String studentDiscountCode = 'verified_student';
  static const String seniorCitizenDiscountCode = 'verified_senior_citizen';

  final int amount;
  final int baseAmount;
  final String currency;
  final String ruleCode;
  final String ruleLabel;
  final int distanceMeters;
  final int barangayHopEstimate;
  final bool isOutsideBuenavista;
  final String? pickupBarangay;
  final String? dropoffBarangay;
  final int driverPickupSurcharge;
  final int? driverToPickupDistanceMeters;
  final int driverPickupBarangayHopEstimate;
  final int discountAmount;
  final double discountRate;
  final String? discountCode;
  final String? discountLabel;

  const FareEstimate({
    required this.amount,
    int? baseAmount,
    this.currency = 'PHP',
    required this.ruleCode,
    required this.ruleLabel,
    required this.distanceMeters,
    required this.barangayHopEstimate,
    required this.isOutsideBuenavista,
    this.pickupBarangay,
    this.dropoffBarangay,
    this.driverPickupSurcharge = 0,
    this.driverToPickupDistanceMeters,
    this.driverPickupBarangayHopEstimate = 1,
    this.discountAmount = 0,
    this.discountRate = 0,
    this.discountCode,
    this.discountLabel,
  }) : baseAmount = baseAmount ?? amount;

  String get amountLabel => '$currency $amount';
  String get baseAmountLabel => '$currency $baseAmount';
  String get discountAmountLabel => '$currency $discountAmount';
  String get driverPickupSurchargeLabel => '$currency $driverPickupSurcharge';
  bool get hasDiscount => discountAmount > 0 && amount < baseAmount;
  bool get hasDriverPickupSurcharge => driverPickupSurcharge > 0;

  FareEstimate applyStudentDiscount({
    required bool isEligible,
    double discountRate = studentDiscountRate,
  }) {
    return applyDiscount(
      isEligible: isEligible,
      discountRate: discountRate,
      discountCode: studentDiscountCode,
      discountLabel: '${_formatPercent(discountRate)}% student discount',
    );
  }

  FareEstimate applyDiscount({
    required bool isEligible,
    required double discountRate,
    required String discountCode,
    required String discountLabel,
  }) {
    final originalAmount = baseAmount;
    final activeDiscountRate = discountRate.clamp(0.0, 1.0).toDouble();
    if (!isEligible || originalAmount <= 0) {
      return _copyWithFare(
        amount: originalAmount,
        baseAmount: originalAmount,
        discountAmount: 0,
        discountRate: 0,
        discountCode: null,
        discountLabel: null,
      );
    }

    final discountedAmount = (originalAmount * (1 - activeDiscountRate))
        .round()
        .clamp(1, originalAmount)
        .toInt();
    final savings = originalAmount - discountedAmount;

    if (savings <= 0) {
      return _copyWithFare(
        amount: originalAmount,
        baseAmount: originalAmount,
        discountAmount: 0,
        discountRate: 0,
        discountCode: null,
        discountLabel: null,
      );
    }

    return _copyWithFare(
      amount: discountedAmount,
      baseAmount: originalAmount,
      discountAmount: savings,
      discountRate: activeDiscountRate,
      discountCode: discountCode,
      discountLabel: discountLabel,
    );
  }

  static String _formatPercent(double rate) {
    final percent = rate.clamp(0.0, 1.0).toDouble() * 100;
    return percent % 1 == 0
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
  }

  FareEstimate _copyWithFare({
    required int amount,
    required int baseAmount,
    required int discountAmount,
    required double discountRate,
    required String? discountCode,
    required String? discountLabel,
  }) {
    return FareEstimate(
      amount: amount,
      baseAmount: baseAmount,
      currency: currency,
      ruleCode: ruleCode,
      ruleLabel: ruleLabel,
      distanceMeters: distanceMeters,
      barangayHopEstimate: barangayHopEstimate,
      isOutsideBuenavista: isOutsideBuenavista,
      pickupBarangay: pickupBarangay,
      dropoffBarangay: dropoffBarangay,
      driverPickupSurcharge: driverPickupSurcharge,
      driverToPickupDistanceMeters: driverToPickupDistanceMeters,
      driverPickupBarangayHopEstimate: driverPickupBarangayHopEstimate,
      discountAmount: discountAmount,
      discountRate: discountRate,
      discountCode: discountCode,
      discountLabel: discountLabel,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'amount': amount,
      'base_amount': baseAmount,
      'currency': currency,
      'rule_code': ruleCode,
      'rule_label': ruleLabel,
      'distance_meters': distanceMeters,
      'barangay_hop_estimate': barangayHopEstimate,
      'is_outside_buenavista': isOutsideBuenavista,
      'pickup_barangay': pickupBarangay,
      'dropoff_barangay': dropoffBarangay,
      'driver_pickup_surcharge': driverPickupSurcharge,
      'driver_to_pickup_distance_meters': driverToPickupDistanceMeters,
      'driver_pickup_barangay_hop_estimate': driverPickupBarangayHopEstimate,
      'discount_applied': hasDiscount,
      'discount_amount': discountAmount,
      'discount_rate': discountRate,
      if (discountCode != null) 'discount_code': discountCode,
      if (discountLabel != null) 'discount_label': discountLabel,
      'calculated_at': FieldValue.serverTimestamp(),
    };
  }
}
