import 'package:flutter/material.dart';

import '../../models/passenger_payment_method.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../services/payment_method_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/passenger_widgets/passenger_payment_method_card.dart';
import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_payment_methods_page.dart';

class PassengerDashboard extends StatelessWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final bool isVerified;
  final VoidCallback onOpenHistory;
  final RideTrackingService rideTrackingService;

  PassengerDashboard({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.isVerified,
    required this.onOpenHistory,
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
                'A quick view of trips, payment readiness, and safety status.',
            icon: Icons.insights_rounded,
            accentColor: PassengerUi.primary,
          ),
          SizedBox(height: 16),
          _PassengerRideSummary(
            userId: userId,
            passengerType: passengerType,
            rideTrackingService: rideTrackingService,
            onOpenHistory: onOpenHistory,
          ),
          SizedBox(height: 20),
          PassengerSectionHeader(
            title: 'Payment Methods',
            actionLabel: 'Manage',
            onActionTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PassengerPaymentMethodsPage(userId: userId),
              ),
            ),
          ),
          SizedBox(height: 12),
          _DashboardPaymentMethodsPreview(userId: userId),
          SizedBox(height: 20),
          _PassengerSafetyCard(
            isVerified: isVerified,
            passengerType: passengerType,
          ),
        ],
      ),
    );
  }
}

class _PassengerRideSummary extends StatelessWidget {
  final String userId;
  final String passengerType;
  final RideTrackingService rideTrackingService;
  final VoidCallback onOpenHistory;

  const _PassengerRideSummary({
    required this.userId,
    required this.passengerType,
    required this.rideTrackingService,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ride>>(
      stream: rideTrackingService.watchPassengerRides(userId),
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
                'Ride dashboard details could not be loaded. Please try again.',
          );
        }

        final data = _PassengerDashboardData.fromRides(
          snapshot.data ?? <Ride>[],
          passengerType: passengerType,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PassengerInsightCard(data: data),
            SizedBox(height: 14),
            _DashboardMetricGrid(
              metrics: <_DashboardMetric>[
                _DashboardMetric(
                  icon: Icons.route_rounded,
                  label: 'Completed trips',
                  value: data.completedTrips.toString(),
                  helper: 'Finished bookings',
                ),
                _DashboardMetric(
                  icon: Icons.near_me_rounded,
                  label: 'Active rides',
                  value: data.activeRides.toString(),
                  helper: 'Accepted or ongoing',
                ),
                _DashboardMetric(
                  icon: Icons.payments_rounded,
                  label: 'Total spent',
                  value: data.totalSpentLabel,
                  helper: 'Completed rides',
                ),
                _DashboardMetric(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Cashless trips',
                  value: data.cashlessTrips.toString(),
                  helper: 'Online payment rides',
                ),
              ],
            ),
            SizedBox(height: 8),
            PassengerRecentTripsSection(
              passengerId: userId,
              limit: 3,
              title: 'Recent Trips',
              actionLabel: 'See More',
              onViewAllTap: onOpenHistory,
            ),
          ],
        );
      },
    );
  }
}

class _PassengerInsightCard extends StatelessWidget {
  final _PassengerDashboardData data;

  const _PassengerInsightCard({required this.data});

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
              data.hasActiveRide
                  ? Icons.navigation_rounded
                  : Icons.verified_rounded,
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

class _PassengerSafetyCard extends StatelessWidget {
  final bool isVerified;
  final String passengerType;

  const _PassengerSafetyCard({
    required this.isVerified,
    required this.passengerType,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Verification and Safety', style: PassengerUi.cardTitle),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              PassengerStatusChip(
                label: isVerified
                    ? 'Verified account'
                    : 'Optional verification',
                textColor: isVerified
                    ? PassengerUi.successText
                    : PassengerUi.highlightAmber,
                backgroundColor: isVerified
                    ? PassengerUi.successBackground
                    : PassengerUi.warningSoft,
              ),
              if (_isStudent)
                PassengerStatusChip(
                  label: '15% student discount',
                  textColor: PassengerUi.successText,
                  backgroundColor: PassengerUi.successBackground,
                ),
              if (_isSeniorCitizen)
                PassengerStatusChip(
                  label: '15% senior citizen discount',
                  textColor: PassengerUi.successText,
                  backgroundColor: PassengerUi.successBackground,
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(_verificationMessage, style: PassengerUi.bodyText),
        ],
      ),
    );
  }

  bool get _isStudent => passengerType.trim().toLowerCase() == 'student';
  bool get _isSeniorCitizen =>
      passengerType.trim().toLowerCase() == 'senior_citizen';

  String get _verificationMessage {
    if (isVerified && (_isStudent || _isSeniorCitizen)) {
      return 'Your fare discount is active and your verified badge is displayed on rides.';
    }

    if (isVerified) {
      return 'Your account is verified and your verified badge is displayed on rides.';
    }

    if (_isStudent) {
      return 'Your account is ready for booking rides right away. Once an admin verifies your student ID in Settings, your student discount will activate.';
    }

    if (_isSeniorCitizen) {
      return 'Your account is ready for booking rides right away. Once an admin verifies your ID in Settings, your senior citizen discount will activate.';
    }

    return 'Your account is active and ready for booking rides immediately. You can optionally upload ID documents in Settings.';
  }
}

class _DashboardPaymentMethodsPreview extends StatelessWidget {
  final String userId;
  final PaymentMethodService paymentMethodService;

  _DashboardPaymentMethodsPreview({
    required this.userId,
    PaymentMethodService? paymentMethodService,
  }) : paymentMethodService = paymentMethodService ?? PaymentMethodService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PassengerPaymentMethod>>(
      stream: paymentMethodService.watchPaymentMethods(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load payments',
            description:
                'Payment methods could not be loaded. Please try again.',
          );
        }

        final methods = (snapshot.data ?? <PassengerPaymentMethod>[])
            .take(3)
            .toList();
        if (methods.isEmpty) {
          methods.add(PassengerPaymentMethod.cash(userId: userId));
        }

        return Column(
          children: methods
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == methods.length - 1 ? 0 : 12,
                  ),
                  child: PassengerPaymentMethodCard(method: entry.value),
                ),
              )
              .toList(),
        );
      },
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

class _PassengerDashboardData {
  final int completedTrips;
  final int activeRides;
  final int totalSpent;
  final int cashlessTrips;
  final int studentSavings;

  const _PassengerDashboardData({
    required this.completedTrips,
    required this.activeRides,
    required this.totalSpent,
    required this.cashlessTrips,
    required this.studentSavings,
  });

  factory _PassengerDashboardData.fromRides(
    List<Ride> rides, {
    required String passengerType,
  }) {
    final completed = rides
        .where((ride) => ride.status == RideStatus.completed)
        .toList();
    final totalSpent = completed.fold<int>(
      0,
      (sum, ride) => sum + (ride.fareAmount ?? 0),
    );
    final isStudent = passengerType.trim().toLowerCase() == 'student';

    return _PassengerDashboardData(
      completedTrips: completed.length,
      activeRides: rides.where((ride) => ride.isActive).length,
      totalSpent: totalSpent,
      cashlessTrips: rides
          .where(
            (ride) => ride.usesOnlineCheckout || ride.paymentMethod != 'cash',
          )
          .length,
      studentSavings: isStudent ? (totalSpent * 0.15).round() : 0,
    );
  }

  bool get hasActiveRide => activeRides > 0;

  String get totalSpentLabel => _peso(totalSpent);

  String get headline {
    if (hasActiveRide) {
      return '$activeRides active ride${activeRides == 1 ? '' : 's'}';
    }

    if (completedTrips > 0) {
      return '$completedTrips completed trip${completedTrips == 1 ? '' : 's'}';
    }

    return 'Ready for your first ride';
  }

  String get summary {
    if (hasActiveRide) {
      return 'Monitor the active booking from Home while your dashboard keeps totals updated.';
    }

    if (studentSavings > 0) {
      return 'Estimated student savings from completed rides: ${_peso(studentSavings)}.';
    }

    if (completedTrips > 0) {
      return 'You have spent $totalSpentLabel across completed rides.';
    }

    return 'Book a ride to start building trip history and fare summaries.';
  }

  static String _peso(int amount) => 'PHP $amount';
}
