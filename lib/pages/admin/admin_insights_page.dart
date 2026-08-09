import 'package:flutter/material.dart';

import '../../widgets/driver_rating_leaderboard_panel.dart';
import '../driver_ratings/driver_leaderboard_page.dart';
import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminInsightsPage extends StatelessWidget {
  final String adminId;

  const AdminInsightsPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load user insights: ${usersSnapshot.error}',
            );
          }

          if (!usersSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<AdminBookingRecord>>(
            stream: AdminService.watchBookings(),
            builder: (context, bookingsSnapshot) {
              if (bookingsSnapshot.hasError) {
                return AdminErrorCard(
                  message:
                      'Unable to load trip insights: ${bookingsSnapshot.error}',
                );
              }

              if (!bookingsSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final users = usersSnapshot.data!;
              final bookings = bookingsSnapshot.data!;

              final verifiedDrivers = users
                  .where((user) => user.isDriver && user.isVerified)
                  .length;
              final verifiedPassengers = users
                  .where((user) => user.isPassenger && user.isVerified)
                  .length;
              final unverifiedDrivers = users
                  .where((user) => user.isDriver && user.isPendingVerification)
                  .length;
              final unverifiedPassengers = users
                  .where(
                    (user) => user.isPassenger && user.isPendingVerification,
                  )
                  .length;
              final restrictedAccounts = users
                  .where((user) => !user.isAdmin && user.isBanned)
                  .length;
              final analytics = _InsightsAnalytics.fromData(users, bookings);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionIntro(title: 'Insights and Analytics'),
                  SizedBox(height: 16),
                  _InsightsTopGrid(
                    metrics: _InsightsMetricsPanel(
                      verifiedDrivers: verifiedDrivers,
                      verifiedPassengers: verifiedPassengers,
                      unverifiedDrivers: unverifiedDrivers,
                      unverifiedPassengers: unverifiedPassengers,
                      restrictedAccounts: restrictedAccounts,
                      adminId: adminId,
                    ),
                    leaderboard: _InsightsSurfacePanel(
                      title: 'Driver Leaderboard',
                      subtitle:
                          'Top-rated drivers ranked for service quality review.',
                      accentColor: AdminUi.highlightAmber,
                      child: DriverRatingLeaderboardPanel(
                        limit: 20,
                        title: 'Driver Leaderboard',
                        actionLabel: 'Open',
                        showWeightedScore: true,
                        onActionTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DriverLeaderboardPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _InsightsAnalyticsGrid(analytics: analytics),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _InsightsTopGrid extends StatelessWidget {
  final Widget metrics;
  final Widget leaderboard;

  const _InsightsTopGrid({required this.metrics, required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final twoColumns = constraints.maxWidth >= 1040;
        final leftWidth = twoColumns
            ? ((constraints.maxWidth - spacing) * 0.42)
            : constraints.maxWidth;
        final rightWidth = twoColumns
            ? constraints.maxWidth - spacing - leftWidth
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(width: leftWidth, child: metrics),
            SizedBox(width: rightWidth, child: leaderboard),
          ],
        );
      },
    );
  }
}

class _InsightsAnalyticsGrid extends StatelessWidget {
  final _InsightsAnalytics analytics;

  const _InsightsAnalyticsGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final twoColumns = constraints.maxWidth >= 920;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(
              width: itemWidth,
              child: _RideVolumeCard(analytics: analytics),
            ),
            SizedBox(
              width: itemWidth,
              child: _PassengerFrequencyCard(analytics: analytics),
            ),
            SizedBox(
              width: itemWidth,
              child: _TopAreaCard(analytics: analytics),
            ),
            SizedBox(
              width: itemWidth,
              child: _FareTotalCard(analytics: analytics),
            ),
            SizedBox(
              width: itemWidth,
              child: _CommissionTotalCard(analytics: analytics),
            ),
          ],
        );
      },
    );
  }
}

class _InsightsAnalytics {
  final _PeriodCount dailyRides;
  final _PeriodCount weeklyRides;
  final _PeriodCount monthlyRides;
  final _PassengerFrequency dailyPassengers;
  final _PassengerFrequency weeklyPassengers;
  final _PassengerFrequency monthlyPassengers;
  final _TopAreaInsight dailyAreas;
  final _TopAreaInsight weeklyAreas;
  final _TopAreaInsight monthlyAreas;
  final _PeriodMoney dailyFare;
  final _PeriodMoney weeklyFare;
  final _PeriodMoney monthlyFare;
  final _PeriodMoney dailyCommission;
  final _PeriodMoney weeklyCommission;
  final _PeriodMoney monthlyCommission;

  const _InsightsAnalytics({
    required this.dailyRides,
    required this.weeklyRides,
    required this.monthlyRides,
    required this.dailyPassengers,
    required this.weeklyPassengers,
    required this.monthlyPassengers,
    required this.dailyAreas,
    required this.weeklyAreas,
    required this.monthlyAreas,
    required this.dailyFare,
    required this.weeklyFare,
    required this.monthlyFare,
    required this.dailyCommission,
    required this.weeklyCommission,
    required this.monthlyCommission,
  });

  factory _InsightsAnalytics.fromData(
    List<AdminUserRecord> users,
    List<AdminBookingRecord> bookings,
  ) {
    final usersById = <String, AdminUserRecord>{
      for (final user in users) user.userId: user,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final previousMonthStart = DateTime(now.year, now.month - 1);

    final todayBookings = _bookingsInRange(bookings, today, tomorrow);
    final yesterdayBookings = _bookingsInRange(bookings, yesterday, today);
    final weekBookings = _bookingsInRange(bookings, weekStart, nextWeekStart);
    final previousWeekBookings = _bookingsInRange(
      bookings,
      previousWeekStart,
      weekStart,
    );
    final monthBookings = _bookingsInRange(
      bookings,
      monthStart,
      nextMonthStart,
    );
    final previousMonthBookings = _bookingsInRange(
      bookings,
      previousMonthStart,
      monthStart,
    );

    return _InsightsAnalytics(
      dailyRides: _PeriodCount(
        label: 'Today',
        value: todayBookings.length,
        previousValue: yesterdayBookings.length,
        previousLabel: 'yesterday',
      ),
      weeklyRides: _PeriodCount(
        label: 'This week',
        value: weekBookings.length,
        previousValue: previousWeekBookings.length,
        previousLabel: 'last week',
      ),
      monthlyRides: _PeriodCount(
        label: 'This month',
        value: monthBookings.length,
        previousValue: previousMonthBookings.length,
        previousLabel: 'last month',
      ),
      dailyPassengers: _PassengerFrequency.fromBookings(
        label: 'Today',
        bookings: todayBookings,
        previousBookings: yesterdayBookings,
        usersById: usersById,
        previousLabel: 'yesterday',
      ),
      weeklyPassengers: _PassengerFrequency.fromBookings(
        label: 'This week',
        bookings: weekBookings,
        previousBookings: previousWeekBookings,
        usersById: usersById,
        previousLabel: 'last week',
      ),
      monthlyPassengers: _PassengerFrequency.fromBookings(
        label: 'This month',
        bookings: monthBookings,
        previousBookings: previousMonthBookings,
        usersById: usersById,
        previousLabel: 'last month',
      ),
      dailyAreas: _TopAreaInsight.fromBookings(
        label: 'Today',
        bookings: todayBookings,
        previousBookings: yesterdayBookings,
        previousLabel: 'yesterday',
      ),
      weeklyAreas: _TopAreaInsight.fromBookings(
        label: 'This week',
        bookings: weekBookings,
        previousBookings: previousWeekBookings,
        previousLabel: 'last week',
      ),
      monthlyAreas: _TopAreaInsight.fromBookings(
        label: 'This month',
        bookings: monthBookings,
        previousBookings: previousMonthBookings,
        previousLabel: 'last month',
      ),
      dailyFare: _PeriodMoney.fromBookings(
        label: 'Today',
        bookings: todayBookings,
        previousBookings: yesterdayBookings,
        previousLabel: 'yesterday',
      ),
      weeklyFare: _PeriodMoney.fromBookings(
        label: 'This week',
        bookings: weekBookings,
        previousBookings: previousWeekBookings,
        previousLabel: 'last week',
      ),
      monthlyFare: _PeriodMoney.fromBookings(
        label: 'This month',
        bookings: monthBookings,
        previousBookings: previousMonthBookings,
        previousLabel: 'last month',
      ),
      dailyCommission: _PeriodMoney.fromCommissionBookings(
        label: 'Today',
        bookings: bookings,
        start: today,
        end: tomorrow,
        previousStart: yesterday,
        previousEnd: today,
        previousLabel: 'yesterday',
      ),
      weeklyCommission: _PeriodMoney.fromCommissionBookings(
        label: 'This week',
        bookings: bookings,
        start: weekStart,
        end: nextWeekStart,
        previousStart: previousWeekStart,
        previousEnd: weekStart,
        previousLabel: 'last week',
      ),
      monthlyCommission: _PeriodMoney.fromCommissionBookings(
        label: 'This month',
        bookings: bookings,
        start: monthStart,
        end: nextMonthStart,
        previousStart: previousMonthStart,
        previousEnd: monthStart,
        previousLabel: 'last month',
      ),
    );
  }

  static List<AdminBookingRecord> _bookingsInRange(
    List<AdminBookingRecord> bookings,
    DateTime start,
    DateTime end,
  ) {
    return bookings
        .where((booking) {
          final timestamp = booking.timestamp;
          return timestamp != null &&
              !timestamp.isBefore(start) &&
              timestamp.isBefore(end);
        })
        .toList(growable: false);
  }
}

class _PeriodCount {
  final String label;
  final int value;
  final int previousValue;
  final String previousLabel;

  const _PeriodCount({
    required this.label,
    required this.value,
    required this.previousValue,
    required this.previousLabel,
  });

  int get difference => value - previousValue;
}

class _PassengerFrequency {
  final String label;
  final int regular;
  final int student;
  final int senior;
  final int previousRegular;
  final int previousStudent;
  final int previousSenior;
  final String previousLabel;

  const _PassengerFrequency({
    required this.label,
    required this.regular,
    required this.student,
    required this.senior,
    required this.previousRegular,
    required this.previousStudent,
    required this.previousSenior,
    required this.previousLabel,
  });

  factory _PassengerFrequency.fromBookings({
    required String label,
    required List<AdminBookingRecord> bookings,
    required List<AdminBookingRecord> previousBookings,
    required Map<String, AdminUserRecord> usersById,
    required String previousLabel,
  }) {
    int countByCondition(
      List<AdminBookingRecord> source,
      bool Function(AdminUserRecord?) predicate,
    ) {
      return source
          .where((booking) => predicate(usersById[booking.passengerId]))
          .length;
    }

    final students = countByCondition(
      bookings,
      (u) => u?.isStudentPassenger == true,
    );
    final previousStudents = countByCondition(
      previousBookings,
      (u) => u?.isStudentPassenger == true,
    );
    final seniors = countByCondition(
      bookings,
      (u) => u?.isSeniorCitizenPassenger == true,
    );
    final previousSeniors = countByCondition(
      previousBookings,
      (u) => u?.isSeniorCitizenPassenger == true,
    );

    return _PassengerFrequency(
      label: label,
      regular: bookings.length - students - seniors,
      student: students,
      senior: seniors,
      previousRegular:
          previousBookings.length - previousStudents - previousSeniors,
      previousStudent: previousStudents,
      previousSenior: previousSeniors,
      previousLabel: previousLabel,
    );
  }

  int get total => regular + student + senior;
  int get previousTotal => previousRegular + previousStudent + previousSenior;
  int get difference => total - previousTotal;
}

class _TopAreaInsight {
  final String label;
  final String pickupArea;
  final int pickupCount;
  final int previousPickupCount;
  final String dropoffArea;
  final int dropoffCount;
  final int previousDropoffCount;
  final String previousLabel;

  const _TopAreaInsight({
    required this.label,
    required this.pickupArea,
    required this.pickupCount,
    required this.previousPickupCount,
    required this.dropoffArea,
    required this.dropoffCount,
    required this.previousDropoffCount,
    required this.previousLabel,
  });

  factory _TopAreaInsight.fromBookings({
    required String label,
    required List<AdminBookingRecord> bookings,
    required List<AdminBookingRecord> previousBookings,
    required String previousLabel,
  }) {
    final pickup = _topArea(bookings.map((booking) => booking.pickupLocation));
    final previousPickup = _topArea(
      previousBookings.map((booking) => booking.pickupLocation),
    );
    final dropoff = _topArea(
      bookings.map((booking) => booking.dropoffLocation),
    );
    final previousDropoff = _topArea(
      previousBookings.map((booking) => booking.dropoffLocation),
    );

    return _TopAreaInsight(
      label: label,
      pickupArea: pickup.area,
      pickupCount: pickup.count,
      previousPickupCount: previousPickup.count,
      dropoffArea: dropoff.area,
      dropoffCount: dropoff.count,
      previousDropoffCount: previousDropoff.count,
      previousLabel: previousLabel,
    );
  }

  static _AreaCount _topArea(Iterable<String> locations) {
    final counts = <String, int>{};
    for (final location in locations) {
      final area = _cleanArea(location);
      if (area.isEmpty || area.toLowerCase() == 'unknown') {
        continue;
      }
      counts[area] = (counts[area] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return const _AreaCount(area: 'No data yet', count: 0);
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.first;
    return _AreaCount(area: top.key, count: top.value);
  }

  static String _cleanArea(String location) {
    final firstPart = location
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .firstOrNull;
    final value = firstPart ?? location.trim();
    return value.length > 34 ? '${value.substring(0, 31)}...' : value;
  }
}

class _AreaCount {
  final String area;
  final int count;

  const _AreaCount({required this.area, required this.count});
}

class _PeriodMoney {
  final String label;
  final double value;
  final double previousValue;
  final String previousLabel;

  const _PeriodMoney({
    required this.label,
    required this.value,
    required this.previousValue,
    required this.previousLabel,
  });

  factory _PeriodMoney.fromBookings({
    required String label,
    required List<AdminBookingRecord> bookings,
    required List<AdminBookingRecord> previousBookings,
    required String previousLabel,
  }) {
    return _PeriodMoney(
      label: label,
      value: _sumFares(bookings),
      previousValue: _sumFares(previousBookings),
      previousLabel: previousLabel,
    );
  }

  factory _PeriodMoney.fromCommissionBookings({
    required String label,
    required List<AdminBookingRecord> bookings,
    required DateTime start,
    required DateTime end,
    required DateTime previousStart,
    required DateTime previousEnd,
    required String previousLabel,
  }) {
    return _PeriodMoney(
      label: label,
      value: _sumCommissions(bookings, start, end),
      previousValue: _sumCommissions(bookings, previousStart, previousEnd),
      previousLabel: previousLabel,
    );
  }

  double get difference => value - previousValue;

  static double _sumFares(List<AdminBookingRecord> bookings) {
    return bookings.fold<double>(
      0,
      (total, booking) => total + _readFareAmount(booking.fareLabel),
    );
  }

  static double _sumCommissions(
    List<AdminBookingRecord> bookings,
    DateTime start,
    DateTime end,
  ) {
    return bookings
        .where((booking) {
          final completedAt = booking.completedAt ?? booking.timestamp;
          return booking.isCompleted &&
              completedAt != null &&
              !completedAt.isBefore(start) &&
              completedAt.isBefore(end);
        })
        .fold<double>(0, (total, booking) => total + booking.commissionAmount);
  }

  static double _readFareAmount(String? fareLabel) {
    final text = fareLabel ?? '';
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

class _RideVolumeCard extends StatelessWidget {
  final _InsightsAnalytics analytics;

  const _RideVolumeCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return _InsightsSurfacePanel(
      title: 'Ride Volume Analytics',
      subtitle: 'Daily, weekly, and monthly ride frequency.',
      accentColor: AdminUi.accentBlue,
      child: Column(
        children: [
          _MiniBarChart(
            values: [
              _ChartValue(label: 'Day', value: analytics.dailyRides.value),
              _ChartValue(label: 'Week', value: analytics.weeklyRides.value),
              _ChartValue(label: 'Month', value: analytics.monthlyRides.value),
            ],
            color: AdminUi.accentBlue,
          ),
          SizedBox(height: 14),
          _PeriodComparisonRow.count(data: analytics.dailyRides),
          _PeriodComparisonRow.count(data: analytics.weeklyRides),
          _PeriodComparisonRow.count(data: analytics.monthlyRides),
        ],
      ),
    );
  }
}

class _PassengerFrequencyCard extends StatelessWidget {
  final _InsightsAnalytics analytics;

  const _PassengerFrequencyCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return _InsightsSurfacePanel(
      title: 'Passenger Type Frequency',
      subtitle: 'Passenger type usage across active periods.',
      accentColor: AdminUi.secondary,
      child: Column(
        children: [
          _PassengerSplitBar(data: analytics.monthlyPassengers),
          SizedBox(height: 14),
          _PassengerPeriodRow(data: analytics.dailyPassengers),
          _PassengerPeriodRow(data: analytics.weeklyPassengers),
          _PassengerPeriodRow(data: analytics.monthlyPassengers),
        ],
      ),
    );
  }
}

class _TopAreaCard extends StatelessWidget {
  final _InsightsAnalytics analytics;

  const _TopAreaCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return _InsightsSurfacePanel(
      title: 'Highest Pickup and Drop-off Areas',
      subtitle: 'Most frequent locations by period.',
      accentColor: AdminUi.highlightAmber,
      child: Column(
        children: [
          _AreaPeriodRow(data: analytics.dailyAreas),
          _AreaPeriodRow(data: analytics.weeklyAreas),
          _AreaPeriodRow(data: analytics.monthlyAreas),
        ],
      ),
    );
  }
}

class _FareTotalCard extends StatelessWidget {
  final _InsightsAnalytics analytics;

  const _FareTotalCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return _InsightsSurfacePanel(
      title: 'Estimated Cash Generated / Spent',
      subtitle: 'Estimated fare totals from available booking fare labels.',
      accentColor: AdminUi.primary,
      child: Column(
        children: [
          _MiniBarChart(
            values: [
              _ChartValue(label: 'Day', value: analytics.dailyFare.value),
              _ChartValue(label: 'Week', value: analytics.weeklyFare.value),
              _ChartValue(label: 'Month', value: analytics.monthlyFare.value),
            ],
            color: AdminUi.primary,
            money: true,
          ),
          SizedBox(height: 14),
          _PeriodComparisonRow.money(data: analytics.dailyFare),
          _PeriodComparisonRow.money(data: analytics.weeklyFare),
          _PeriodComparisonRow.money(data: analytics.monthlyFare),
        ],
      ),
    );
  }
}

class _CommissionTotalCard extends StatelessWidget {
  final _InsightsAnalytics analytics;

  const _CommissionTotalCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return _InsightsSurfacePanel(
      title: 'System Commission Totals',
      subtitle: 'Commission earned from completed rides only.',
      accentColor: AdminUi.secondary,
      child: Column(
        children: [
          _MiniBarChart(
            values: [
              _ChartValue(label: 'Day', value: analytics.dailyCommission.value),
              _ChartValue(
                label: 'Week',
                value: analytics.weeklyCommission.value,
              ),
              _ChartValue(
                label: 'Month',
                value: analytics.monthlyCommission.value,
              ),
            ],
            color: AdminUi.secondary,
            money: true,
          ),
          SizedBox(height: 14),
          _PeriodComparisonRow.money(data: analytics.dailyCommission),
          _PeriodComparisonRow.money(data: analytics.weeklyCommission),
          _PeriodComparisonRow.money(data: analytics.monthlyCommission),
        ],
      ),
    );
  }
}

class _ChartValue {
  final String label;
  final num value;

  const _ChartValue({required this.label, required this.value});
}

class _MiniBarChart extends StatelessWidget {
  final List<_ChartValue> values;
  final Color color;
  final bool money;

  const _MiniBarChart({
    required this.values,
    required this.color,
    this.money = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<num>(
      1,
      (current, item) => item.value > current ? item.value : current,
    );

    return SizedBox(
      height: 144,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values
            .map((item) {
              final factor = (item.value / maxValue).clamp(0.0, 1.0).toDouble();

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        money
                            ? _formatMoney(item.value.toDouble())
                            : item.value.round().toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminUi.labelText.copyWith(
                          color: AdminUi.title,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableHeight = constraints.maxHeight;
                            final minHeight = availableHeight < 24
                                ? availableHeight
                                : 24.0;
                            final height =
                                minHeight +
                                ((availableHeight - minHeight) * factor);

                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                width: double.infinity,
                                height: height,
                                constraints: const BoxConstraints(maxWidth: 44),
                                decoration: BoxDecoration(
                                  color: Color.lerp(
                                    color,
                                    AdminUi.secondary,
                                    factor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.14),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        height: 16,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminUi.labelText.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _PassengerSplitBar extends StatelessWidget {
  final _PassengerFrequency data;

  const _PassengerSplitBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.total == 0 ? 1 : data.total;
    final regularFlex = data.regular == 0 ? 1 : data.regular;
    final studentFlex = data.student == 0 ? 1 : data.student;
    final seniorFlex = data.senior == 0 ? 1 : data.senior;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                Expanded(
                  flex: regularFlex,
                  child: ColoredBox(color: AdminUi.accentBlue),
                ),
                Expanded(
                  flex: studentFlex,
                  child: ColoredBox(color: AdminUi.secondary),
                ),
                Expanded(
                  flex: seniorFlex,
                  child: ColoredBox(color: AdminUi.highlightAmber),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _LegendLabel(
              color: AdminUi.accentBlue,
              label: 'Regular',
              value:
                  '${data.regular} (${((data.regular / total) * 100).round()}%)',
            ),
            _LegendLabel(
              color: AdminUi.secondary,
              label: 'Student',
              value:
                  '${data.student} (${((data.student / total) * 100).round()}%)',
            ),
            _LegendLabel(
              color: AdminUi.highlightAmber,
              label: 'Senior Citizen',
              value:
                  '${data.senior} (${((data.senior / total) * 100).round()}%)',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendLabel extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendLabel({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            '$label $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.labelText.copyWith(color: AdminUi.body),
          ),
        ),
      ],
    );
  }
}

class _PeriodComparisonRow extends StatelessWidget {
  final String label;
  final String value;
  final num difference;
  final String previousLabel;

  const _PeriodComparisonRow({
    required this.label,
    required this.value,
    required this.difference,
    required this.previousLabel,
  });

  factory _PeriodComparisonRow.count({required _PeriodCount data}) {
    return _PeriodComparisonRow(
      label: data.label,
      value: data.value.toString(),
      difference: data.difference,
      previousLabel: data.previousLabel,
    );
  }

  factory _PeriodComparisonRow.money({required _PeriodMoney data}) {
    return _PeriodComparisonRow(
      label: data.label,
      value: _formatMoney(data.value),
      difference: data.difference,
      previousLabel: data.previousLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InsightRowShell(
      label: label,
      value: value,
      trailing: _ComparisonChip(
        difference: difference,
        previousLabel: previousLabel,
      ),
    );
  }
}

class _PassengerPeriodRow extends StatelessWidget {
  final _PassengerFrequency data;

  const _PassengerPeriodRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return _InsightRowShell(
      label: data.label,
      value:
          '${data.regular} regular / ${data.student} student / ${data.senior} senior',
      trailing: _ComparisonChip(
        difference: data.difference,
        previousLabel: data.previousLabel,
      ),
    );
  }
}

class _AreaPeriodRow extends StatelessWidget {
  final _TopAreaInsight data;

  const _AreaPeriodRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminUi.surface.withValues(
            alpha: AdminUi.isDarkMode ? 0.55 : 1,
          ),
          borderRadius: AdminUi.radius,
          border: Border.all(color: AdminUi.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(data.label, style: AdminUi.cardTitle)),
                _ComparisonChip(
                  difference:
                      (data.pickupCount + data.dropoffCount) -
                      (data.previousPickupCount + data.previousDropoffCount),
                  previousLabel: data.previousLabel,
                ),
              ],
            ),
            SizedBox(height: 8),
            _AreaLine(
              label: 'Pickup',
              area: data.pickupArea,
              count: data.pickupCount,
              color: AdminUi.accentBlue,
            ),
            SizedBox(height: 6),
            _AreaLine(
              label: 'Drop-off',
              area: data.dropoffArea,
              count: data.dropoffCount,
              color: AdminUi.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaLine extends StatelessWidget {
  final String label;
  final String area;
  final int count;
  final Color color;

  const _AreaLine({
    required this.label,
    required this.area,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        SizedBox(width: 62, child: Text(label, style: AdminUi.labelText)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            area,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.bodyText,
          ),
        ),
        SizedBox(width: 8),
        Text('$count', style: AdminUi.cardTitle),
      ],
    );
  }
}

class _InsightRowShell extends StatelessWidget {
  final String label;
  final String value;
  final Widget trailing;

  const _InsightRowShell({
    required this.label,
    required this.value,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AdminUi.surface.withValues(
            alpha: AdminUi.isDarkMode ? 0.55 : 1,
          ),
          borderRadius: AdminUi.radius,
          border: Border.all(color: AdminUi.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AdminUi.labelText),
                  SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.cardTitle,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ComparisonChip extends StatelessWidget {
  final num difference;
  final String previousLabel;

  const _ComparisonChip({
    required this.difference,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context) {
    final positive = difference > 0;
    final neutral = difference == 0;
    final color = neutral
        ? AdminUi.body
        : positive
        ? AdminUi.successText
        : AdminUi.danger;
    final prefix = neutral
        ? ''
        : positive
        ? '+'
        : '';
    final formatted = difference is double
        ? _formatMoney(difference.toDouble())
        : '$prefix${difference.round()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AdminUi.soft(color, alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$formatted vs $previousLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdminUi.labelText.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

String _formatMoney(double value) {
  final sign = value < 0 ? '-' : '';
  final absolute = value.abs();
  if (absolute >= 1000000) {
    return '${sign}PHP ${(absolute / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '${sign}PHP ${(absolute / 1000).toStringAsFixed(1)}K';
  }
  return '${sign}PHP ${absolute.toStringAsFixed(0)}';
}

class _InsightsMetricsPanel extends StatelessWidget {
  final int verifiedDrivers;
  final int verifiedPassengers;
  final int unverifiedDrivers;
  final int unverifiedPassengers;
  final int restrictedAccounts;
  final String adminId;

  const _InsightsMetricsPanel({
    required this.verifiedDrivers,
    required this.verifiedPassengers,
    required this.unverifiedDrivers,
    required this.unverifiedPassengers,
    required this.restrictedAccounts,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return _InsightsSurfacePanel(
      title: 'Quality Metrics',
      subtitle: 'Verification and moderation indicators for service quality.',
      accentColor: AdminUi.accentBlue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final columns = _metricColumns(constraints.maxWidth);
          final cardWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _MetricFrame(
                width: cardWidth,
                child: _CompactInsightMetricCard(
                  label: 'Verified drivers',
                  value: verifiedDrivers.toString(),
                  icon: Icons.badge_rounded,
                  accentColor: AdminUi.primary,
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: _CompactInsightMetricCard(
                  label: 'Verified passengers',
                  value: verifiedPassengers.toString(),
                  icon: Icons.verified_user_rounded,
                  accentColor: AdminUi.secondary,
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: _CompactInsightMetricCard(
                  label: 'Unverified drivers',
                  value: unverifiedDrivers.toString(),
                  icon: Icons.two_wheeler_rounded,
                  accentColor: AdminUi.highlightAmber,
                  onTap: () => AdminNavigation.openUnverifiedDrivers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: _CompactInsightMetricCard(
                  label: 'Unverified passengers',
                  value: unverifiedPassengers.toString(),
                  icon: Icons.person_search_rounded,
                  accentColor: AdminUi.accentBlue,
                  onTap: () => AdminNavigation.openUnverifiedPassengers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: _CompactInsightMetricCard(
                  label: 'Restricted users',
                  value: restrictedAccounts.toString(),
                  icon: Icons.gpp_bad_rounded,
                  accentColor: AdminUi.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static int _metricColumns(double width) {
    if (width >= 620) return 3;
    if (width >= 420) return 2;
    return 1;
  }
}

class _InsightsSurfacePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _InsightsSurfacePanel({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final background = AdminUi.isDarkMode
        ? Color.lerp(AdminUi.surface, accentColor, 0.10)
        : AdminUi.surface;

    return AdminSurfaceCard(
      color: background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AdminUi.cardTitle),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminUi.bodyText.copyWith(
                        color: AdminUi.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CompactInsightMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const _CompactInsightMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = AdminUi.isDarkMode
        ? Color.lerp(AdminUi.surface, accentColor, 0.08)
        : AdminUi.surface;

    final content = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AdminUi.soft(accentColor, alpha: 0.12),
            borderRadius: AdminUi.radius,
            border: Border.all(color: accentColor.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminUi.labelText.copyWith(
                  color: AdminUi.body,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminUi.valueText.copyWith(
                  color: AdminUi.title,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.north_east_rounded, size: 14, color: AdminUi.muted),
      ],
    );

    if (onTap != null) {
      return AdminInteractiveCard(
        onTap: onTap!,
        padding: const EdgeInsets.all(10),
        color: background,
        accentColor: accentColor,
        semanticLabel: 'Open $label insight',
        child: content,
      );
    }

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(10),
      color: background,
      child: content,
    );
  }
}

class _MetricFrame extends StatelessWidget {
  final double width;
  final Widget child;

  const _MetricFrame({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: 72, child: child);
  }
}
