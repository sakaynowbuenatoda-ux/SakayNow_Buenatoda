import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/driver_earnings_summary.dart';
import 'package:sakaynow_buenatoda/models/ride_earnings.dart';
import 'package:sakaynow_buenatoda/models/ride_status.dart';

import '../support/ride_fixture.dart';

void main() {
  test('calculates rounded commission and driver net earnings', () {
    final earnings = RideEarningsBreakdown.calculate(
      grossFare: 25,
      commissionRate: 0.10,
    );

    expect(earnings.grossFare, 25);
    expect(earnings.commissionRate, 0.10);
    expect(earnings.commissionAmount, 3);
    expect(earnings.driverNetEarnings, 22);
    expect(earnings.toFirestore(), <String, dynamic>{
      'gross_fare': 25,
      'commission_rate': 0.10,
      'commission_amount': 3,
      'driver_net_earnings': 22,
    });
  });

  test('defaults legacy completed rides to zero commission', () {
    final ride = buildRideFixture(status: RideStatus.completed, fareAmount: 50);

    expect(ride.grossEarningsAmount, 50);
    expect(ride.commissionDeductionAmount, 0);
    expect(ride.netEarningsAmount, 50);
    expect(ride.commissionRateLabel, '0%');
  });

  test('summarizes today and lifetime gross commission and net totals', () {
    final now = DateTime(2026, 8, 8, 12);
    final rides = [
      buildRideFixture(
        status: RideStatus.completed,
        grossFare: 100,
        commissionRate: 0.10,
        commissionAmount: 10,
        driverNetEarnings: 90,
        paymentMethod: 'gcash',
        paymentProvider: 'xendit',
        paymentStatus: 'paid',
        driverPayoutStatus: 'pending',
        completedAt: now,
      ),
      buildRideFixture(
        status: RideStatus.completed,
        fareAmount: 50,
        completedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    final summary = DriverEarningsSummary.fromRides(rides, now: now);

    expect(summary.todayGross, 100);
    expect(summary.todayCommission, 10);
    expect(summary.todayNet, 90);
    expect(summary.lifetimeGross, 150);
    expect(summary.lifetimeCommission, 10);
    expect(summary.lifetimeNet, 140);
    expect(summary.pendingCashlessPayouts, 1);
    expect(summary.cashlessPayoutStatusLabel, '1 cashless payout pending');
  });
}
