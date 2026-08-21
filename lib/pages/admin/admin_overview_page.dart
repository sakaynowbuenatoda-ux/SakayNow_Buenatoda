import 'package:flutter/material.dart';

import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminOverviewPage extends StatelessWidget {
  final String adminId;
  final String firstName;

  const AdminOverviewPage({
    super.key,
    required this.adminId,
    required this.firstName,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load users: ${usersSnapshot.error}',
            );
          }

          if (!usersSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<AdminUserRecord>>(
            stream: AdminService.watchActiveDrivers(),
            builder: (context, activeDriversSnapshot) {
              if (activeDriversSnapshot.hasError) {
                return AdminErrorCard(
                  message:
                      'Users loaded, but active drivers could not be read: ${activeDriversSnapshot.error}',
                );
              }

              if (!activeDriversSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<AdminBookingRecord>>(
                stream: AdminService.watchBookings(),
                builder: (context, bookingsSnapshot) {
                  if (bookingsSnapshot.hasError) {
                    return AdminErrorCard(
                      message:
                          'Users loaded, but bookings could not be read: ${bookingsSnapshot.error}',
                    );
                  }

                  if (!bookingsSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<List<AdminReportRecord>>(
                    stream: AdminService.watchReports(),
                    builder: (context, reportsSnapshot) {
                      if (reportsSnapshot.hasError) {
                        return AdminErrorCard(
                          message:
                              'Bookings loaded, but reports could not be read: ${reportsSnapshot.error}',
                        );
                      }

                      if (!reportsSnapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final users = usersSnapshot.data!;
                      final activeDrivers = activeDriversSnapshot.data!;
                      final bookings = bookingsSnapshot.data!;
                      final reports = reportsSnapshot.data!;
                      final overview = _AdminOverviewData.fromData(
                        users,
                        bookings,
                        reports,
                        activeDrivers.length,
                      );
                      final usersById = <String, AdminUserRecord>{
                        for (final user in users) user.userId: user,
                      };

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminSectionIntro(title: 'Admin Panel'),
                          SizedBox(height: 16),
                          _OverviewMetricPanel(
                            overview: overview,
                            adminId: adminId,
                          ),
                          SizedBox(height: 20),
                          _OverviewInsightGrid(
                            overview: overview,
                            reports: reports,
                            usersById: usersById,
                          ),
                          SizedBox(height: 20),
                          const _RecentBookingActivityHeader(),
                          SizedBox(height: 12),
                          if (bookings.isEmpty)
                            AdminEmptyCollection(
                              icon: Icons.route_outlined,
                              title: 'No trip activity yet',
                              description:
                                  'Once passengers start requesting rides, this section will summarize the most recent booking flow.',
                            )
                          else
                            ...bookings.take(3).map((booking) {
                              final passenger =
                                  usersById[booking.passengerId]?.fullName ??
                                  'Passenger';
                              final driver =
                                  usersById[booking.driverId]?.fullName ??
                                  'Unassigned';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AdminBookingCard(
                                  booking: booking,
                                  passengerName: passenger,
                                  driverName: driver,
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RecentBookingActivityHeader extends StatelessWidget {
  const _RecentBookingActivityHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Text(
          'Recent Booking Activity',
          style: AdminUi.sectionTitle,
        );
        final action = AdminActionButton(
          label: 'See All',
          icon: Icons.arrow_forward_rounded,
          backgroundColor: AdminUi.blueSoft,
          foregroundColor: AdminUi.accentBlue,
          onPressed: () => AdminNavigation.openBookingHistory(context),
        );

        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[title, const SizedBox(height: 10), action],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }
}

class _AdminOverviewData {
  final int totalUsers;
  final int unverifiedDrivers;
  final int unverifiedPassengers;
  final int pendingDocumentReviews;
  final int activeDrivers;
  final int expiredDriverDocuments;
  final int completedBookings;
  final int activeBookings;
  final int todayRequestedBookings;
  final int todayAcceptedBookings;
  final int todayCompletedBookings;
  final int todayCancelledBookings;
  final int openReports;
  final List<_DailyBookingCount> dailyBookingCounts;

  const _AdminOverviewData({
    required this.totalUsers,
    required this.unverifiedDrivers,
    required this.unverifiedPassengers,
    required this.pendingDocumentReviews,
    required this.activeDrivers,
    required this.expiredDriverDocuments,
    required this.completedBookings,
    required this.activeBookings,
    required this.todayRequestedBookings,
    required this.todayAcceptedBookings,
    required this.todayCompletedBookings,
    required this.todayCancelledBookings,
    required this.openReports,
    required this.dailyBookingCounts,
  });

  factory _AdminOverviewData.fromData(
    List<AdminUserRecord> users,
    List<AdminBookingRecord> bookings,
    List<AdminReportRecord> reports,
    int activeDriverCount,
  ) {
    final registeredUsers = users.where((user) => user.isPassengerOrDriver);
    final unverifiedDrivers = users
        .where((user) => user.isDriver && user.isPendingVerification)
        .length;
    final unverifiedPassengers = users
        .where((user) => user.isPassenger && user.isPendingVerification)
        .length;
    final pendingDocumentReviews = users
        .where((user) => user.hasReviewOnlySubmission)
        .length;
    final todayBookings = bookings.where(_isToday).toList(growable: false);

    return _AdminOverviewData(
      totalUsers: registeredUsers.length,
      unverifiedDrivers: unverifiedDrivers,
      unverifiedPassengers: unverifiedPassengers,
      pendingDocumentReviews: pendingDocumentReviews,
      activeDrivers: activeDriverCount,
      expiredDriverDocuments: users
          .where((user) => user.hasExpiredDriverDocuments)
          .length,
      completedBookings: bookings
          .where((booking) => booking.isCompleted)
          .length,
      activeBookings: bookings.where((booking) => booking.isActiveTrip).length,
      todayRequestedBookings: todayBookings.length,
      todayAcceptedBookings: todayBookings
          .where((booking) => booking.isActiveTrip)
          .length,
      todayCompletedBookings: todayBookings
          .where((booking) => booking.isCompleted)
          .length,
      todayCancelledBookings: todayBookings
          .where((booking) => booking.isCancelled)
          .length,
      openReports: reports.where((report) => report.isOpen).length,
      dailyBookingCounts: _buildDailyBookingCounts(bookings),
    );
  }

  static bool _isToday(AdminBookingRecord booking) {
    final timestamp = booking.timestamp;
    if (timestamp == null) {
      return false;
    }

    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  static List<_DailyBookingCount> _buildDailyBookingCounts(
    List<AdminBookingRecord> bookings,
  ) {
    final now = DateTime.now();
    final days = List<DateTime>.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return DateTime(date.year, date.month, date.day);
    });

    return days
        .map((day) {
          final nextDay = day.add(const Duration(days: 1));
          final count = bookings.where((booking) {
            final timestamp = booking.timestamp;
            return timestamp != null &&
                !timestamp.isBefore(day) &&
                timestamp.isBefore(nextDay);
          }).length;

          return _DailyBookingCount(day: day, count: count);
        })
        .toList(growable: false);
  }
}

class _DailyBookingCount {
  final DateTime day;
  final int count;

  const _DailyBookingCount({required this.day, required this.count});
}

class _OverviewMetricPanel extends StatelessWidget {
  final _AdminOverviewData overview;
  final String adminId;

  const _OverviewMetricPanel({required this.overview, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'Platform Metrics',
      subtitle: 'Tap any metric to open its detailed admin view',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final width = constraints.maxWidth;
          final columns = _metricColumns(width);
          final cardWidth = (width - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Registered users',
                  value: overview.totalUsers.toString(),
                  helper: 'Passengers and drivers',
                  icon: Icons.groups_rounded,
                  accentColor: AdminUi.primary,
                  onTap: () => AdminNavigation.openRegisteredUsers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Unverified drivers',
                  value: overview.unverifiedDrivers.toString(),
                  helper: 'New accounts awaiting verification',
                  icon: Icons.two_wheeler_rounded,
                  accentColor: AdminUi.highlightAmber,
                  onTap: () => AdminNavigation.openUnverifiedDrivers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Unverified passengers',
                  value: overview.unverifiedPassengers.toString(),
                  helper: 'New accounts awaiting verification',
                  icon: Icons.person_outline_rounded,
                  accentColor: AdminUi.accentBlue,
                  onTap: () => AdminNavigation.openUnverifiedPassengers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Document reviews',
                  value: overview.pendingDocumentReviews.toString(),
                  helper: 'Verified-user updates awaiting review',
                  icon: Icons.fact_check_outlined,
                  accentColor: AdminUi.highlightAmber,
                  onTap: () => AdminNavigation.openDocumentReviews(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Active drivers',
                  value: overview.activeDrivers.toString(),
                  helper: 'Online and trackable',
                  icon: Icons.local_taxi_rounded,
                  accentColor: AdminUi.secondary,
                  onTap: () => AdminNavigation.openActiveDrivers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Expired documents',
                  value: overview.expiredDriverDocuments.toString(),
                  helper: 'Verified drivers requiring renewal',
                  icon: Icons.event_busy_rounded,
                  accentColor: AdminUi.danger,
                  onTap: () => AdminNavigation.openExpiredDriverDocuments(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Completed trips',
                  value: overview.completedBookings.toString(),
                  helper: 'Finished bookings in system',
                  icon: Icons.route_rounded,
                  accentColor: AdminUi.successText,
                  onTap: () => AdminNavigation.openCompletedTrips(context),
                ),
              ),
              _MetricTileFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Trips in motion',
                  value: overview.activeBookings.toString(),
                  helper: 'Accepted or ongoing',
                  icon: Icons.radar_rounded,
                  accentColor: AdminUi.accentBlue,
                  onTap: () => AdminNavigation.openTripsInMotion(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static int _metricColumns(double width) {
    if (width >= 1180) return 5;
    if (width >= 900) return 4;
    if (width >= 640) return 3;
    if (width >= 360) return 2;
    return 1;
  }
}

class _MetricTileFrame extends StatelessWidget {
  final double width;
  final Widget child;

  const _MetricTileFrame({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: 128, child: child);
  }
}

class _OverviewInsightGrid extends StatelessWidget {
  final _AdminOverviewData overview;
  final List<AdminReportRecord> reports;
  final Map<String, AdminUserRecord> usersById;

  const _OverviewInsightGrid({
    required this.overview,
    required this.reports,
    required this.usersById,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final wide = constraints.maxWidth >= 920;
        final compactSummary = constraints.maxWidth < 560;
        final cards = <Widget>[
          _TodayRideSummaryCard(overview: overview, compact: compactSummary),
          _SystemHealthCard(overview: overview),
          _RecentReportsCard(reports: reports, usersById: usersById),
          _BookingAnalyticsCard(overview: overview),
        ];

        if (!wide) {
          return Column(
            children: <Widget>[
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: spacing),
                cards[index],
              ],
            ],
          );
        }

        return Column(
          children: <Widget>[
            _EqualHeightOverviewRow(
              spacing: spacing,
              left: cards[0],
              right: cards[1],
            ),
            const SizedBox(height: spacing),
            _EqualHeightOverviewRow(
              spacing: spacing,
              left: cards[2],
              right: cards[3],
            ),
          ],
        );
      },
    );
  }
}

class _EqualHeightOverviewRow extends StatelessWidget {
  final double spacing;
  final Widget left;
  final Widget right;

  const _EqualHeightOverviewRow({
    required this.spacing,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: left),
          SizedBox(width: spacing),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _TodayRideSummaryCard extends StatelessWidget {
  final _AdminOverviewData overview;
  final bool compact;

  const _TodayRideSummaryCard({required this.overview, required this.compact});

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: "Today's Ride Summary",
      subtitle: 'Live booking movement for today',
      child: _RideSummaryStats(
        compact: compact,
        stats: <_RideSummaryStat>[
          _RideSummaryStat(
            label: 'Requested',
            value: overview.todayRequestedBookings.toString(),
            color: AdminUi.primary,
          ),
          _RideSummaryStat(
            label: 'Accepted',
            value: overview.todayAcceptedBookings.toString(),
            color: AdminUi.accentBlue,
          ),
          _RideSummaryStat(
            label: 'Completed',
            value: overview.todayCompletedBookings.toString(),
            color: AdminUi.successText,
          ),
          _RideSummaryStat(
            label: 'Cancelled',
            value: overview.todayCancelledBookings.toString(),
            color: AdminUi.danger,
          ),
        ],
      ),
    );
  }
}

class _RecentReportsCard extends StatelessWidget {
  final List<AdminReportRecord> reports;
  final Map<String, AdminUserRecord> usersById;

  const _RecentReportsCard({required this.reports, required this.usersById});

  @override
  Widget build(BuildContext context) {
    final recentReports = reports.take(3).toList(growable: false);

    return AdminSectionCard(
      title: 'Recent Reports',
      subtitle: 'Latest service issues from passengers and drivers',
      child: recentReports.isEmpty
          ? _InlineEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No reports yet',
              description: 'New reports will appear here for quick triage.',
            )
          : Column(
              children: recentReports.indexed
                  .map((entry) {
                    final index = entry.$1;
                    final report = entry.$2;
                    final reporter =
                        usersById[report.reporterId]?.fullName ??
                        report.reporterRoleLabel;
                    final reported =
                        usersById[report.reportedUserId]?.fullName ??
                        report.reportedUserRoleLabel;

                    return _ReportIssueTile(
                      title: report.reasonLabel,
                      subtitle: '$reporter reported $reported',
                      status: report.reportStatus,
                      isLast: index == recentReports.length - 1,
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  final _AdminOverviewData overview;

  const _SystemHealthCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'System Health',
      subtitle: 'Live admin dashboard data is available',
      child: Column(
        children: [
          _HealthRow(
            label: 'Account profiles',
            value: '${overview.totalUsers} profiles synced',
            color: AdminUi.successText,
            isLast: false,
          ),
          _HealthRow(
            label: 'Booking stream',
            value: '${overview.activeBookings} active trips tracked',
            color: AdminUi.accentBlue,
            isLast: false,
          ),
          _HealthRow(
            label: 'Open reports',
            value: '${overview.openReports} waiting for action',
            color: overview.openReports == 0
                ? AdminUi.successText
                : AdminUi.highlightAmber,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _BookingAnalyticsCard extends StatelessWidget {
  final _AdminOverviewData overview;

  const _BookingAnalyticsCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: '7-Day Booking Trend',
      subtitle: 'Short graph analytics from booking timestamps',
      child: _BookingBarChart(values: overview.dailyBookingCounts),
    );
  }
}

class _RideSummaryStat {
  final String label;
  final String value;
  final Color color;

  const _RideSummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _RideSummaryStats extends StatelessWidget {
  final bool compact;
  final List<_RideSummaryStat> stats;

  const _RideSummaryStats({required this.compact, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats
                .map(
                  (stat) => SizedBox(
                    width: tileWidth,
                    child: _MiniStatPill(stat: stat),
                  ),
                )
                .toList(growable: false),
          );
        },
      );
    }

    return Row(
      children: <Widget>[
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _MiniStatPill(stat: stats[index])),
        ],
      ],
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final _RideSummaryStat stat;

  const _MiniStatPill({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminUi.subtleSurface,
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.valueText.copyWith(
              color: AdminUi.title,
              fontSize: 21,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: stat.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.labelText.copyWith(
                    color: AdminUi.body,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportIssueTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final AdminReportStatus status;
  final bool isLast;

  const _ReportIssueTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminReportStatus.pending => AdminUi.highlightAmber,
      AdminReportStatus.resolved => AdminUi.successText,
      AdminReportStatus.ignored => AdminUi.muted,
      AdminReportStatus.spam => AdminUi.danger,
    };

    return Container(
      padding: EdgeInsets.only(top: 9, bottom: isLast ? 2 : 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AdminUi.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AdminUi.subtleSurface,
              borderRadius: AdminUi.radius,
              border: Border.all(color: AdminUi.border),
            ),
            child: Icon(Icons.report_outlined, size: 17, color: AdminUi.title),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.cardTitle.copyWith(
                    color: AdminUi.title,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.bodyText.copyWith(
                    color: AdminUi.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MinimalStatusBadge(label: status.label, color: color),
        ],
      ),
    );
  }
}

class _MinimalStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MinimalStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AdminUi.subtleSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AdminUi.labelText.copyWith(
              color: AdminUi.title,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isLast;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 9, bottom: isLast ? 2 : 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AdminUi.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 11),
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminUi.cardTitle.copyWith(
                color: AdminUi.title,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AdminUi.bodyText.copyWith(
                color: AdminUi.body,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBarChart extends StatelessWidget {
  final List<_DailyBookingCount> values;

  const _BookingBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(
      1,
      (current, item) => item.count > current ? item.count : current,
    );

    return SizedBox(
      height: 176,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: values
            .map((item) {
              final heightFactor = item.count / maxValue;
              final barHeight = item.count == 0
                  ? 0.0
                  : 10 + (92 * heightFactor);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Text(
                        item.count.toString(),
                        style: AdminUi.labelText.copyWith(
                          color: AdminUi.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 26,
                            decoration: BoxDecoration(
                              color: AdminUi.subtleSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AdminUi.border),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: AdminUi.title,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weekdayLabel(item.day.weekday),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminUi.labelText.copyWith(fontSize: 11),
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

  static String _weekdayLabel(int weekday) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AdminUi.mutedSurface,
            borderRadius: AdminUi.radius,
          ),
          child: Icon(icon, color: AdminUi.secondary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminUi.cardTitle),
              const SizedBox(height: 3),
              Text(description, style: AdminUi.bodyText),
            ],
          ),
        ),
      ],
    );
  }
}
