import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminMonitoringPage extends StatelessWidget {
  final String adminId;

  const AdminMonitoringPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
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
              final bookings = bookingsSnapshot.data!;
              final usersById = <String, AdminUserRecord>{
                for (final user in users) user.userId: user,
              };
              final monitoring = _AdminMonitoringData.fromData(users, bookings);
              final liveBookings = bookings
                  .where((booking) => booking.isQueued || booking.isActiveTrip)
                  .take(6)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionIntro(title: 'Monitoring'),
                  SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 390;
                      final spacing = compact ? 10.0 : 12.0;
                      final cardWidth = (constraints.maxWidth - spacing) / 2;

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
                              accentColor: PassengerUi.accentBlue,
                              actionLabel: 'Open live trips',
                              onTap: () =>
                                  AdminNavigation.openTripsInMotion(context),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Queue',
                              value: monitoring.queuedTrips.toString(),
                              helper: 'Waiting for assignment',
                              icon: Icons.pending_actions_rounded,
                              accentColor: PassengerUi.highlightAmber,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Available drivers',
                              value: monitoring.availableDrivers.toString(),
                              helper: 'Verified and active',
                              icon: Icons.two_wheeler_rounded,
                              accentColor: PassengerUi.secondary,
                              actionLabel: 'Open drivers',
                              onTap: () => AdminNavigation.openActiveDrivers(
                                context,
                                adminId: adminId,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Unassigned',
                              value: monitoring.unassignedTrips.toString(),
                              helper: 'Trips without driver id',
                              icon: Icons.person_off_outlined,
                              accentColor: PassengerUi.primary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Live Ride Flow', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  if (liveBookings.isEmpty)
                    AdminEmptyCollection(
                      icon: Icons.route_outlined,
                      title: 'No live rides to monitor',
                      description:
                          'Queued and active bookings will appear here as passengers request rides.',
                    )
                  else
                    ...liveBookings.map((booking) {
                      final passenger =
                          usersById[booking.passengerId]?.fullName ??
                          'Passenger';
                      final driver =
                          usersById[booking.driverId]?.fullName ?? 'Unassigned';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminBookingCard(
                          booking: booking,
                          passengerName: passenger,
                          driverName: driver,
                        ),
                      );
                    }),
                  SizedBox(height: 8),
                  Text('System Health', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Dispatch readiness',
                    icon: Icons.health_and_safety_rounded,
                    accentColor: PassengerUi.secondary,
                    description:
                        '${monitoring.availableDrivers} active driver(s) are ready for ${monitoring.queuedTrips} queued request(s). Monitor this ratio during peak hours to avoid passenger wait times.',
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Verification pressure',
                    icon: Icons.fact_check_rounded,
                    accentColor: PassengerUi.highlightAmber,
                    description:
                        '${monitoring.pendingVerification} account(s) still need approval before they can fully use the platform.',
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Completed service volume',
                    icon: Icons.task_alt_rounded,
                    accentColor: PassengerUi.successText,
                    description:
                        '${monitoring.completedTrips} completed trip record(s) are available for admin review and service tracking.',
                  ),
                ],
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
  ) {
    return _AdminMonitoringData(
      activeTrips: bookings.where((booking) => booking.isActiveTrip).length,
      queuedTrips: bookings.where((booking) => booking.isQueued).length,
      completedTrips: bookings.where((booking) => booking.isCompleted).length,
      availableDrivers: users
          .where((user) => user.isDriver && user.isVerified && user.isActive)
          .length,
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
