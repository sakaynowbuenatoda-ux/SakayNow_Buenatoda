import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminReportsPage extends StatelessWidget {
  final String adminId;

  const AdminReportsPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load report users: ${usersSnapshot.error}',
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
                      'Unable to load report bookings: ${bookingsSnapshot.error}',
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
              final reports = _AdminReportsData.fromData(users, bookings);
              final cancelledBookings = bookings
                  .where((booking) => booking.isCancelled)
                  .take(4)
                  .toList(growable: false);
              final restrictedUsers = users
                  .where((user) => !user.isAdmin && user.isBanned)
                  .take(4)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionIntro(title: 'Reports'),
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
                              label: 'Open signals',
                              value: reports.openSignals.toString(),
                              helper: 'Accounts or trips needing review',
                              icon: Icons.report_problem_rounded,
                              accentColor: PassengerUi.primary,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Cancelled trips',
                              value: reports.cancelledTrips.toString(),
                              helper: 'Rejected or cancelled bookings',
                              icon: Icons.cancel_schedule_send_rounded,
                              accentColor: PassengerUi.highlightAmber,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Restricted users',
                              value: reports.restrictedUsers.toString(),
                              helper: 'Accounts with safety action',
                              icon: Icons.gpp_bad_rounded,
                              accentColor: PassengerUi.primary,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Pending IDs',
                              value: reports.pendingVerification.toString(),
                              helper: 'Verification reports to inspect',
                              icon: Icons.fact_check_outlined,
                              accentColor: PassengerUi.accentBlue,
                              actionLabel: 'Open queues',
                              onTap: () =>
                                  AdminNavigation.openUnverifiedDrivers(
                                    context,
                                    adminId: adminId,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Incident Review', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  if (cancelledBookings.isEmpty)
                    AdminEmptyCollection(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'No cancelled trip reports',
                      description:
                          'Cancelled and rejected bookings will appear here for follow-up.',
                    )
                  else
                    ...cancelledBookings.map((booking) {
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
                  Text('Restricted Accounts', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  if (restrictedUsers.isEmpty)
                    AdminInfoPanel(
                      title: 'No restricted accounts',
                      icon: Icons.verified_user_rounded,
                      accentColor: PassengerUi.successText,
                      description:
                          'There are no restricted passenger or driver accounts in the current users collection.',
                    )
                  else
                    ...restrictedUsers.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminUserCard(
                          user: user,
                          hintLabel:
                              'Review this account before restoring access.',
                          actions: [
                            AdminActionButton(
                              label: 'Restore',
                              onPressed: () => AdminService.restoreUser(
                                userId: user.userId,
                                adminId: adminId,
                              ),
                              backgroundColor: PassengerUi.successBackground,
                              foregroundColor: PassengerUi.successText,
                              icon: Icons.restore_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  Text('Report Readiness', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Moderation queue',
                    icon: Icons.security_rounded,
                    accentColor: PassengerUi.accentBlue,
                    description:
                        'This page now gives admins a dedicated place for trip incidents, restricted accounts, and verification signals while a dedicated reports collection is prepared.',
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

class _AdminReportsData {
  final int cancelledTrips;
  final int restrictedUsers;
  final int pendingVerification;

  const _AdminReportsData({
    required this.cancelledTrips,
    required this.restrictedUsers,
    required this.pendingVerification,
  });

  int get openSignals => cancelledTrips + restrictedUsers + pendingVerification;

  factory _AdminReportsData.fromData(
    List<AdminUserRecord> users,
    List<AdminBookingRecord> bookings,
  ) {
    return _AdminReportsData(
      cancelledTrips: bookings.where((booking) => booking.isCancelled).length,
      restrictedUsers: users
          .where((user) => !user.isAdmin && user.isBanned)
          .length,
      pendingVerification: users
          .where((user) => user.isPendingVerification)
          .length,
    );
  }
}
