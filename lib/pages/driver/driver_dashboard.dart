import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../models/driver_payout_account.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../services/driver_payout_account_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/driver_widgets/driver_payout_account_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../driver_ratings/driver_leaderboard_page.dart';
import 'driver_payout_accounts_page.dart';

const String _leaderboardAnimationAsset =
    'assets/animations/leaderboard_pulse.json';

class DriverDashboardPage extends StatelessWidget {
  final String driverId;
  final bool isVerified;
  final RideTrackingService rideTrackingService;

  DriverDashboardPage({
    super.key,
    required this.driverId,
    required this.isVerified,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Dashboard',
            subtitle:
                'Monitor performance, queue readiness, and account standing.',
            icon: Icons.dashboard_rounded,
            accentColor: PassengerUi.primary,
          ),
          SizedBox(height: 16),
          _DriverRideSummary(
            driverId: driverId,
            isVerified: isVerified,
            rideTrackingService: rideTrackingService,
          ),
          SizedBox(height: 20),
          PassengerSectionHeader(
            title: 'Payout Accounts',
            actionLabel: 'Manage',
            onActionTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DriverPayoutAccountsPage(driverId: driverId),
              ),
            ),
          ),
          SizedBox(height: 12),
          _DriverPayoutAccountsPreview(driverId: driverId),
        ],
      ),
    );
  }
}

class _DriverRideSummary extends StatelessWidget {
  final String driverId;
  final bool isVerified;
  final RideTrackingService rideTrackingService;

  const _DriverRideSummary({
    required this.driverId,
    required this.isVerified,
    required this.rideTrackingService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ride>>(
      stream: rideTrackingService.watchDriverRides(driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load dashboard',
            description:
                'Driver dashboard details could not be loaded. Please try again.',
          );
        }

        final data = _DriverDashboardData.fromRides(snapshot.data ?? <Ride>[]);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DriverInsightCard(data: data),
            SizedBox(height: 14),
            _DashboardMetricGrid(
              metrics: <_DashboardMetric>[
                _DashboardMetric(
                  icon: Icons.payments_rounded,
                  label: 'Today earnings',
                  value: data.todayEarningsLabel,
                  helper: 'Completed today',
                ),
                _DashboardMetric(
                  icon: Icons.route_rounded,
                  label: 'Completed rides',
                  value: data.completedTrips.toString(),
                  helper: 'All finished trips',
                ),
                _DashboardMetric(
                  icon: Icons.near_me_rounded,
                  label: 'Active trips',
                  value: data.activeTrips.toString(),
                  helper: 'Accepted or ongoing',
                ),
                _DashboardMetric(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Cashless trips',
                  value: data.cashlessTrips.toString(),
                  helper: 'Online payment rides',
                ),
              ],
            ),
            SizedBox(height: 14),
            _DriverStandingCard(
              driverId: driverId,
              isVerified: isVerified,
              rideTrackingService: rideTrackingService,
            ),
            SizedBox(height: 14),
            _DriverLatestRideCard(data: data),
          ],
        );
      },
    );
  }
}

class _DriverInsightCard extends StatelessWidget {
  final _DriverDashboardData data;

  const _DriverInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: PassengerUi.successBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              data.activeTrips > 0
                  ? Icons.navigation_rounded
                  : Icons.trending_up_rounded,
              color: PassengerUi.successText,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(data.headline, style: PassengerUi.cardTitle),
                SizedBox(height: 4),
                Text(data.summary, style: PassengerUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverLatestRideCard extends StatelessWidget {
  final _DriverDashboardData data;

  const _DriverLatestRideCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ride = data.latestRide;
    if (ride == null) {
      return const PassengerEmptyState(
        icon: Icons.route_outlined,
        title: 'No driver trips yet',
        description:
            'Accepted bookings, earnings, and route summaries will appear here after your first trip.',
      );
    }

    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Latest trip', style: PassengerUi.cardTitle),
              ),
              PassengerStatusChip(
                label: ride.status.label,
                textColor: ride.status == RideStatus.cancelled
                    ? PassengerUi.primary
                    : PassengerUi.successText,
                backgroundColor: ride.status == RideStatus.cancelled
                    ? PassengerUi.dangerSoft
                    : PassengerUi.successBackground,
              ),
            ],
          ),
          SizedBox(height: 12),
          _DashboardDetailRow(
            icon: Icons.place_rounded,
            label: 'Drop-off',
            value: ride.dropoffLocation.publicDisplayLabel,
          ),
          SizedBox(height: 10),
          _DashboardDetailRow(
            icon: Icons.payments_rounded,
            label: 'Fare',
            value: ride.fareLabel ?? 'Pending fare',
          ),
          SizedBox(height: 10),
          _DashboardDetailRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Payment',
            value: ride.paymentMethodDisplayLabel,
          ),
        ],
      ),
    );
  }
}

class _DriverPayoutAccountsPreview extends StatelessWidget {
  final String driverId;
  final DriverPayoutAccountService payoutAccountService;

  _DriverPayoutAccountsPreview({
    required this.driverId,
    DriverPayoutAccountService? payoutAccountService,
  }) : payoutAccountService =
           payoutAccountService ?? DriverPayoutAccountService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverPayoutAccount>>(
      stream: payoutAccountService.watchPayoutAccounts(driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load payout accounts',
            description:
                'Payout accounts could not be loaded. Please try again.',
          );
        }

        final accounts = (snapshot.data ?? <DriverPayoutAccount>[])
            .take(2)
            .toList();
        if (accounts.isEmpty) {
          return PassengerSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Online payments are cash only',
                  style: PassengerUi.cardTitle,
                ),
                SizedBox(height: 6),
                Text(
                  'Add GCash, Maya, or bank account details so passengers can choose Xendit checkout when booking you.',
                  style: PassengerUi.bodyText,
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DriverPayoutAccountsPage(driverId: driverId),
                      ),
                    ),
                    icon: Icon(Icons.add_rounded),
                    label: Text('Add Payout Account'),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: accounts
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == accounts.length - 1 ? 0 : 12,
                  ),
                  child: DriverPayoutAccountCard(account: entry.value),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DriverStandingCard extends StatelessWidget {
  final String driverId;
  final bool isVerified;
  final RideTrackingService rideTrackingService;

  const _DriverStandingCard({
    required this.driverId,
    required this.isVerified,
    required this.rideTrackingService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DriverReviewProfile>(
      stream: rideTrackingService.watchDriverProfile(driverId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final ratingLabel = profile?.ratingLabel ?? 'No ratings yet';
        final reviewCount = profile?.reviewCount ?? 0;
        final weightedLabel = profile?.weightedRatingLabel ?? 'Not ranked';
        final ratingRank = profile?.ratingRank;
        final hasTop20Rank =
            ratingRank != null && ratingRank >= 1 && ratingRank <= 20;
        final rankLabel = hasTop20Rank ? '#${profile!.ratingRank}' : '';

        return InkWell(
          borderRadius: PassengerUi.cardRadius,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  DriverLeaderboardPage(highlightDriverId: driverId),
            ),
          ),
          child: PassengerSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: PassengerUi.warningSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Lottie.asset(
                        _leaderboardAnimationAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Standing', style: PassengerUi.cardTitle),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to view the Top 20 leaderboard.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PassengerUi.bodyText.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: PassengerUi.blueSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.leaderboard_rounded,
                        size: 18,
                        color: PassengerUi.accentBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _StandingMetricPill(
                      icon: isVerified
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded,
                      label: isVerified ? 'Verified driver' : 'Pending review',
                      color: isVerified
                          ? PassengerUi.successText
                          : PassengerUi.primary,
                    ),
                    _StandingMetricPill(
                      icon: Icons.star_rounded,
                      label: ratingLabel,
                      color: PassengerUi.highlightAmber,
                    ),
                    _StandingMetricPill(
                      icon: Icons.rate_review_rounded,
                      label:
                          '$reviewCount review${reviewCount == 1 ? '' : 's'}',
                      color: PassengerUi.accentBlue,
                    ),
                    if (rankLabel.isNotEmpty)
                      _StandingMetricPill(
                        icon: Icons.workspace_premium_rounded,
                        label: rankLabel,
                        color: PassengerUi.highlightAmber,
                      ),
                    _StandingMetricPill(
                      icon: Icons.trending_up_rounded,
                      label: 'Rank Score $weightedLabel',
                      color: PassengerUi.secondary,
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      _StandingMetricPill(
                        icon: Icons.sync_rounded,
                        label: 'Syncing',
                        color: PassengerUi.body,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  Text(
                    'Ratings could not be loaded right now. Your verification status is still shown from the active session.',
                    style: PassengerUi.bodyText,
                  )
                else
                  Text(
                    isVerified
                        ? 'Rank score combines your average rating with review volume for fair leaderboard placement.'
                        : 'You can access your driver home, but profile editing and active ride features stay limited until admin verification is complete.',
                    style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StandingMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StandingMetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PassengerUi.valueText.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricGrid extends StatelessWidget {
  final List<_DashboardMetric> metrics;

  const _DashboardMetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 1 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: compact ? 3.35 : 1.72,
      ),
      itemBuilder: (context, index) =>
          _DashboardMetricCard(metric: metrics[index]),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final _DashboardMetric metric;

  const _DashboardMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: PassengerUi.accentBlue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12),
                ),
                SizedBox(height: 3),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  metric.helper,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DashboardDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: PassengerUi.accentBlue, size: 18),
        SizedBox(width: 10),
        Text(label, style: PassengerUi.bodyText),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: PassengerUi.valueText,
          ),
        ),
      ],
    );
  }
}

class _DashboardMetric {
  final IconData icon;
  final String label;
  final String value;
  final String helper;

  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });
}

class _DriverDashboardData {
  final int completedTrips;
  final int activeTrips;
  final int todayEarnings;
  final int totalEarnings;
  final int cashlessTrips;
  final Ride? latestRide;

  const _DriverDashboardData({
    required this.completedTrips,
    required this.activeTrips,
    required this.todayEarnings,
    required this.totalEarnings,
    required this.cashlessTrips,
    required this.latestRide,
  });

  factory _DriverDashboardData.fromRides(List<Ride> rides) {
    final now = DateTime.now();
    final completed = rides
        .where((ride) => ride.status == RideStatus.completed)
        .toList();
    final todayCompleted = completed.where((ride) {
      final date = ride.updatedAt ?? ride.createdAt;
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    });

    return _DriverDashboardData(
      completedTrips: completed.length,
      activeTrips: rides.where((ride) => ride.isActive).length,
      todayEarnings: todayCompleted.fold<int>(
        0,
        (sum, ride) => sum + (ride.fareAmount ?? 0),
      ),
      totalEarnings: completed.fold<int>(
        0,
        (sum, ride) => sum + (ride.fareAmount ?? 0),
      ),
      cashlessTrips: rides
          .where(
            (ride) => ride.usesOnlineCheckout || ride.paymentMethod != 'cash',
          )
          .length,
      latestRide: rides.isEmpty ? null : rides.first,
    );
  }

  String get todayEarningsLabel => _peso(todayEarnings);

  String get headline {
    if (activeTrips > 0) {
      return '$activeTrips active trip${activeTrips == 1 ? '' : 's'}';
    }

    if (todayEarnings > 0) {
      return '$todayEarningsLabel earned today';
    }

    if (completedTrips > 0) {
      return '$completedTrips completed trip${completedTrips == 1 ? '' : 's'}';
    }

    return 'Ready for first trip';
  }

  String get summary {
    if (activeTrips > 0) {
      return 'Keep your driver location updated while active trips are in progress.';
    }

    if (completedTrips > 0) {
      return 'Lifetime fare total from completed rides is ${_peso(totalEarnings)}.';
    }

    return 'Accept bookings from the queue to start tracking earnings and trip performance.';
  }

  static String _peso(int amount) => 'PHP $amount';
}
