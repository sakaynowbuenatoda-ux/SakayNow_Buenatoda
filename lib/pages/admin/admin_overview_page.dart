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
    return _ModernOverviewCard(
      title: 'Platform Metrics',
      subtitle: 'Tap any metric to open its detailed admin view',
      accentColor: AdminUi.accentBlue,
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
        final cardWidth = wide
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _TodayRideSummaryCard(overview: overview),
            ),
            SizedBox(
              width: cardWidth,
              child: _SystemHealthCard(overview: overview),
            ),
            SizedBox(
              width: cardWidth,
              child: _RecentReportsCard(reports: reports, usersById: usersById),
            ),
            SizedBox(
              width: cardWidth,
              child: _BookingAnalyticsCard(overview: overview),
            ),
          ],
        );
      },
    );
  }
}

class _TodayRideSummaryCard extends StatelessWidget {
  final _AdminOverviewData overview;

  const _TodayRideSummaryCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return _ModernOverviewCard(
      title: "Today's Ride Summary",
      subtitle: 'Live booking movement for today',
      accentColor: AdminUi.accentBlue,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MiniStatPill(
            label: 'Requested',
            value: overview.todayRequestedBookings.toString(),
            color: AdminUi.primary,
          ),
          _MiniStatPill(
            label: 'Accepted',
            value: overview.todayAcceptedBookings.toString(),
            color: AdminUi.accentBlue,
          ),
          _MiniStatPill(
            label: 'Completed',
            value: overview.todayCompletedBookings.toString(),
            color: AdminUi.successText,
          ),
          _MiniStatPill(
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

    return _ModernOverviewCard(
      title: 'Recent Reports',
      subtitle: 'Latest service issues from passengers and drivers',
      accentColor: AdminUi.highlightAmber,
      child: recentReports.isEmpty
          ? _InlineEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No reports yet',
              description: 'New reports will appear here for quick triage.',
            )
          : Column(
              children: recentReports
                  .map((report) {
                    final reporter =
                        usersById[report.reporterId]?.fullName ??
                        report.reporterRoleLabel;
                    final reported =
                        usersById[report.reportedUserId]?.fullName ??
                        report.reportedUserRoleLabel;

                    return _ReportIssueTile(
                      title: report.reasonLabel,
                      subtitle: '$reporter reported $reported',
                      status: report.statusLabel,
                      isOpen: report.isOpen,
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
    return _ModernOverviewCard(
      title: 'System Health',
      subtitle: 'Live admin dashboard data is available',
      accentColor: AdminUi.secondary,
      child: Column(
        children: [
          _HealthRow(
            label: 'Account profiles',
            value: '${overview.totalUsers} profiles synced',
            color: AdminUi.successText,
          ),
          _HealthRow(
            label: 'Booking stream',
            value: '${overview.activeBookings} active trips tracked',
            color: AdminUi.accentBlue,
          ),
          _HealthRow(
            label: 'Open reports',
            value: '${overview.openReports} waiting for action',
            color: overview.openReports == 0
                ? AdminUi.successText
                : AdminUi.highlightAmber,
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
    return _ModernOverviewCard(
      title: '7-Day Booking Trend',
      subtitle: 'Short graph analytics from booking timestamps',
      accentColor: const Color(0xFF7C3AED),
      child: _BookingBarChart(values: overview.dailyBookingCounts),
    );
  }
}

class _ModernOverviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _ModernOverviewCard({
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
                    const SizedBox(height: 3),
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AdminUi.surface.withValues(alpha: AdminUi.isDarkMode ? 0.55 : 1),
        borderRadius: AdminUi.radius,
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.valueText.copyWith(
              color: color,
              fontSize: 22,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.labelText.copyWith(color: AdminUi.body),
          ),
        ],
      ),
    );
  }
}

class _ReportIssueTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final bool isOpen;

  const _ReportIssueTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AdminUi.highlightAmber : AdminUi.successText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.cardTitle.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.bodyText.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AdminStatusChip(
            label: status,
            textColor: color,
            backgroundColor: AdminUi.soft(color, alpha: 0.12),
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

  const _HealthRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AdminUi.cardTitle)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AdminUi.bodyText.copyWith(fontSize: 12.5),
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
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values
            .map((item) {
              final heightFactor = item.count / maxValue;
              final barHeight = 34 + (86 * heightFactor);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        item.count.toString(),
                        style: AdminUi.labelText.copyWith(
                          color: AdminUi.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        height: barHeight,
                        constraints: const BoxConstraints(maxWidth: 32),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            AdminUi.accentBlue,
                            AdminUi.secondary,
                            heightFactor,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AdminUi.accentBlue.withValues(alpha: 0.14),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
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
