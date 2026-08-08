import 'ride.dart';
import 'ride_status.dart';

class DriverEarningsSummary {
  final int todayGross;
  final int todayCommission;
  final int todayNet;
  final int lifetimeGross;
  final int lifetimeCommission;
  final int lifetimeNet;
  final int completedTrips;
  final int cashlessCompletedTrips;
  final int pendingCashlessPayouts;

  const DriverEarningsSummary({
    required this.todayGross,
    required this.todayCommission,
    required this.todayNet,
    required this.lifetimeGross,
    required this.lifetimeCommission,
    required this.lifetimeNet,
    required this.completedTrips,
    required this.cashlessCompletedTrips,
    required this.pendingCashlessPayouts,
  });

  factory DriverEarningsSummary.fromRides(List<Ride> rides, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final completed = rides
        .where((ride) => ride.status == RideStatus.completed)
        .toList(growable: false);
    final today = completed
        .where((ride) {
          final date = ride.completedAt ?? ride.updatedAt ?? ride.createdAt;
          return date != null &&
              date.year == current.year &&
              date.month == current.month &&
              date.day == current.day;
        })
        .toList(growable: false);
    final cashless = completed
        .where((ride) => ride.usesOnlineCheckout)
        .toList(growable: false);

    int sum(List<Ride> source, int Function(Ride ride) amount) {
      return source.fold<int>(0, (total, ride) => total + amount(ride));
    }

    return DriverEarningsSummary(
      todayGross: sum(today, (ride) => ride.grossEarningsAmount),
      todayCommission: sum(today, (ride) => ride.commissionDeductionAmount),
      todayNet: sum(today, (ride) => ride.netEarningsAmount),
      lifetimeGross: sum(completed, (ride) => ride.grossEarningsAmount),
      lifetimeCommission: sum(
        completed,
        (ride) => ride.commissionDeductionAmount,
      ),
      lifetimeNet: sum(completed, (ride) => ride.netEarningsAmount),
      completedTrips: completed.length,
      cashlessCompletedTrips: cashless.length,
      pendingCashlessPayouts: cashless
          .where((ride) => ride.isCashlessPayoutPending)
          .length,
    );
  }

  String get cashlessPayoutStatusLabel {
    if (cashlessCompletedTrips == 0) {
      return 'No completed cashless payouts yet';
    }
    if (pendingCashlessPayouts > 0) {
      return '$pendingCashlessPayouts cashless payout${pendingCashlessPayouts == 1 ? '' : 's'} pending';
    }
    return 'All cashless payouts are settled';
  }

  static String peso(int amount) => 'PHP $amount';
}
