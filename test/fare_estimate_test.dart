import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/fare_estimate.dart';

void main() {
  FareEstimate estimate({required int amount}) {
    return FareEstimate(
      amount: amount,
      ruleCode: 'test_rule',
      ruleLabel: 'Test rule',
      distanceMeters: 1000,
      barangayHopEstimate: 1,
      isOutsideBuenavista: false,
    );
  }

  test('applies 15 percent discount for verified students', () {
    final discounted = estimate(
      amount: 20,
    ).applyStudentDiscount(isEligible: true);

    expect(discounted.amount, 17);
    expect(discounted.baseAmount, 20);
    expect(discounted.discountAmount, 3);
    expect(discounted.discountRate, 0.15);
    expect(discounted.hasDiscount, isTrue);
  });

  test('keeps base fare when student discount is not eligible', () {
    final regularFare = estimate(
      amount: 30,
    ).applyStudentDiscount(isEligible: false);

    expect(regularFare.amount, 30);
    expect(regularFare.baseAmount, 30);
    expect(regularFare.discountAmount, 0);
    expect(regularFare.hasDiscount, isFalse);
  });
}
