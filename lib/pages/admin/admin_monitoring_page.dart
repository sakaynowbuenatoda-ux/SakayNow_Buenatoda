import 'package:flutter/material.dart';

import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_live_driver_map.dart';
import 'widgets/admin_shared.dart';

class AdminMonitoringPage extends StatelessWidget {
  final String adminId;

  const AdminMonitoringPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return AdminErrorCard(
              message:
                  'Unable to load monitoring users: ${usersSnapshot.error}',
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
                      'Unable to load active drivers: ${activeDriversSnapshot.error}',
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
                          'Unable to load monitoring bookings: ${bookingsSnapshot.error}',
                    );
                  }

                  if (!bookingsSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final users = usersSnapshot.data!;
                  final activeDrivers = activeDriversSnapshot.data!;
                  final bookings = bookingsSnapshot.data!;
                  final usersById = <String, AdminUserRecord>{
                    for (final user in users) user.userId: user,
                  };
                  final monitoring = _AdminMonitoringData.fromData(
                    users,
                    bookings,
                    activeDrivers.length,
                  );
                  final liveBookings = bookings
                      .where(
                        (booking) => booking.isQueued || booking.isActiveTrip,
                      )
                      .take(6)
                      .toList(growable: false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionIntro(
                        title: 'Monitoring',
                        actions: <Widget>[
                          AdminActionButton(
                            label: 'Ride History',
                            icon: Icons.history_rounded,
                            backgroundColor: AdminUi.blueSoft,
                            foregroundColor: AdminUi.accentBlue,
                            onPressed: () =>
                                AdminNavigation.openBookingHistory(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      AdminSectionCard(
                        title: 'Live Operations',
                        subtitle:
                            'Current ride, queue, and driver availability indicators.',
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 12.0;
                            final cardWidth = AdminUi.metricCardWidth(
                              constraints.maxWidth,
                            );

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: AdminMetricCard(
                                    label: 'Live trips',
                                    value: monitoring.activeTrips.toString(),
                                    helper: 'Accepted or ongoing rides',
                                    icon: Icons.radar_rounded,
                                    accentColor: AdminUi.accentBlue,
                                    onTap: () =>
                                        AdminNavigation.openTripsInMotion(
                                          context,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: AdminMetricCard(
                                    label: 'Queue',
                                    value: monitoring.queuedTrips.toString(),
                                    helper: 'Waiting for assignment',
                                    icon: Icons.pending_actions_rounded,
                                    accentColor: AdminUi.highlightAmber,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: AdminMetricCard(
                                    label: 'Online drivers',
                                    value: monitoring.availableDrivers
                                        .toString(),
                                    helper: 'Active and trackable',
                                    icon: Icons.two_wheeler_rounded,
                                    accentColor: AdminUi.secondary,
                                    onTap: () =>
                                        AdminNavigation.openActiveDrivers(
                                          context,
                                          adminId: adminId,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: AdminMetricCard(
                                    label: 'Unassigned',
                                    value: monitoring.unassignedTrips
                                        .toString(),
                                    helper: 'Trips without driver id',
                                    icon: Icons.person_off_outlined,
                                    accentColor: AdminUi.primary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      const AdminLiveDriverMap(),
                      SizedBox(height: 20),
                      AdminSectionCard(
                        title: 'Live Ride Flow',
                        subtitle:
                            '${liveBookings.length} queued or active ride${liveBookings.length == 1 ? '' : 's'} shown.',
                        child: liveBookings.isEmpty
                            ? AdminEmptyCollection(
                                icon: Icons.route_outlined,
                                title: 'No live rides to monitor',
                                description:
                                    'Queued and active bookings will appear here as passengers request rides.',
                              )
                            : Column(
                                children: liveBookings.indexed
                                    .map((entry) {
                                      final index = entry.$1;
                                      final booking = entry.$2;
                                      final passenger =
                                          usersById[booking.passengerId]
                                              ?.fullName ??
                                          'Passenger';
                                      final driver =
                                          usersById[booking.driverId]
                                              ?.fullName ??
                                          'Unassigned';

                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              index == liveBookings.length - 1
                                              ? 0
                                              : 10,
                                        ),
                                        child: AdminBookingCard(
                                          booking: booking,
                                          passengerName: passenger,
                                          driverName: driver,
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                      ),
                      SizedBox(height: 20),
                      AdminSectionCard(
                        title: 'System Health',
                        subtitle:
                            'Operational signals that may need admin attention.',
                        child: Column(
                          children: <Widget>[
                            AdminInfoPanel(
                              title: 'Dispatch readiness',
                              description:
                                  '${monitoring.availableDrivers} online driver(s) are trackable while ${monitoring.queuedTrips} request(s) are queued. Monitor this during peak hours to avoid passenger wait times.',
                            ),
                            SizedBox(height: 10),
                            AdminInfoPanel(
                              title: 'Verification pressure',
                              description:
                                  '${monitoring.pendingVerification} account(s) still need approval before they can fully use the platform.',
                            ),
                            SizedBox(height: 10),
                            AdminInfoPanel(
                              title: 'Completed service volume',
                              description:
                                  '${monitoring.completedTrips} completed trip(s) are available for admin review and service tracking.',
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _AdminMonitoringData {
  final int activeTrips;
  final int queuedTrips;
  final int completedTrips;
  final int availableDrivers;
  final int pendingVerification;
  final int unassignedTrips;

  const _AdminMonitoringData({
    required this.activeTrips,
    required this.queuedTrips,
    required this.completedTrips,
    required this.availableDrivers,
    required this.pendingVerification,
    required this.unassignedTrips,
  });

  factory _AdminMonitoringData.fromData(
    List<AdminUserRecord> users,
    List<AdminBookingRecord> bookings,
    int activeDriverCount,
  ) {
    return _AdminMonitoringData(
      activeTrips: bookings.where((booking) => booking.isActiveTrip).length,
      queuedTrips: bookings.where((booking) => booking.isQueued).length,
      completedTrips: bookings.where((booking) => booking.isCompleted).length,
      availableDrivers: activeDriverCount,
      pendingVerification: users
          .where((user) => user.isPendingVerification)
          .length,
      unassignedTrips: bookings
          .where(
            (booking) =>
                (booking.isQueued || booking.isActiveTrip) &&
                booking.driverId.isEmpty,
          )
          .length,
    );
  }
}
