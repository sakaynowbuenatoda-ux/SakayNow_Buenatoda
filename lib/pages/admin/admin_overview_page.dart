import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
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
    return PassengerPageContainer(
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

              final users = usersSnapshot.data!;
              final bookings = bookingsSnapshot.data!;
              final overview = _AdminOverviewData.fromData(users, bookings);
              final usersById = <String, AdminUserRecord>{
                for (final user in users) user.userId: user,
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionIntro(title: 'Admin Panel'),
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
                              label: 'Registered users',
                              value: overview.totalUsers.toString(),
                              helper: 'All roles in Firestore',
                              icon: Icons.groups_rounded,
                              accentColor: PassengerUi.primary,
                              actionLabel: 'Open users',
                              onTap: () => AdminNavigation.openRegisteredUsers(
                                context,
                                adminId: adminId,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Unverified drivers',
                              value: overview.unverifiedDrivers.toString(),
                              helper: 'Driver accounts waiting for review',
                              icon: Icons.two_wheeler_rounded,
                              accentColor: PassengerUi.highlightAmber,
                              actionLabel: 'Open driver queue',
                              onTap: () =>
                                  AdminNavigation.openUnverifiedDrivers(
                                    context,
                                    adminId: adminId,
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Unverified passengers',
                              value: overview.unverifiedPassengers.toString(),
                              helper: 'Passenger accounts waiting for review',
                              icon: Icons.person_outline_rounded,
                              accentColor: PassengerUi.accentBlue,
                              actionLabel: 'Open passenger queue',
                              onTap: () =>
                                  AdminNavigation.openUnverifiedPassengers(
                                    context,
                                    adminId: adminId,
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Active drivers',
                              value: overview.activeDrivers.toString(),
                              helper: 'Ready to accept bookings',
                              icon: Icons.local_taxi_rounded,
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
                              label: 'Student accounts',
                              value: overview.studentPassengers.toString(),
                              helper: 'Discount-eligible users',
                              icon: Icons.school_rounded,
                              accentColor: PassengerUi.accentBlue,
                              actionLabel: 'Open students',
                              onTap: () => AdminNavigation.openStudentAccounts(
                                context,
                                adminId: adminId,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Completed trips',
                              value: overview.completedBookings.toString(),
                              helper: 'Finished bookings in system',
                              icon: Icons.route_rounded,
                              accentColor: PassengerUi.successText,
                              actionLabel: 'Open trips',
                              onTap: () =>
                                  AdminNavigation.openCompletedTrips(context),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: AdminMetricCard(
                              label: 'Trips in motion',
                              value: overview.activeBookings.toString(),
                              helper: 'Accepted or ongoing',
                              icon: Icons.radar_rounded,
                              accentColor: PassengerUi.accentBlue,
                              actionLabel: 'Open live trips',
                              onTap: () =>
                                  AdminNavigation.openTripsInMotion(context),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  PassengerSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminSectionIntro(
                          title: 'Objective Coverage',
                          subtitle:
                              'This admin UI is organized around the study objectives so the dashboard reflects the full service scope, not only account management.',
                        ),
                        SizedBox(height: 16),
                        AdminCapabilityTile(
                          icon: Icons.touch_app_rounded,
                          title: 'Ride booking visibility',
                          description:
                              'Recent booking activity, queue state, and trip completion are surfaced from the same Firestore flow used by the app.',
                          status: 'Connected to bookings collection',
                          accentColor: PassengerUi.primary,
                        ),
                        AdminCapabilityTile(
                          icon: Icons.location_searching_rounded,
                          title: 'Geofencing and trip monitoring',
                          description:
                              'Trip movement readiness is represented through live booking state tracking so dispatch oversight is visible even before map data is added.',
                          status: 'Operational monitoring ready',
                          accentColor: PassengerUi.accentBlue,
                        ),
                        AdminCapabilityTile(
                          icon: Icons.payments_rounded,
                          title: 'Fare and payment oversight',
                          description:
                              'Fare labels and payment method fields are summarized so LGU fare transparency and cashless readiness can be checked by admins.',
                          status:
                              'Reads booking fare and payment fields when present',
                          accentColor: PassengerUi.secondary,
                        ),
                        AdminCapabilityTile(
                          icon: Icons.star_rate_rounded,
                          title: 'Feedback and reporting readiness',
                          description:
                              'The admin side now reserves structured space for service quality, issue escalation, and future review analytics.',
                          status: 'UI coverage added for ratings and reports',
                          accentColor: PassengerUi.highlightAmber,
                        ),
                        AdminCapabilityTile(
                          icon: Icons.badge_rounded,
                          title: 'Verification and security',
                          description:
                              'Passenger and driver approvals use the existing users collection flags that already control account access in auth.',
                          status:
                              'Directly updates is_verified, is_active, and is_banned',
                          accentColor: PassengerUi.primary,
                        ),
                        AdminCapabilityTile(
                          icon: Icons.monitor_heart_rounded,
                          title: 'System performance monitoring',
                          description:
                              'Overview cards and operational health sections summarize the current platform state for admins in one mobile-friendly dashboard.',
                          status: 'Connected to live users and booking data',
                          accentColor: PassengerUi.accentBlue,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('Review Queues', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 250,
                        child: AdminMetricCard(
                          label: 'Driver Queue',
                          value: overview.unverifiedDrivers.toString(),
                          helper:
                              'Open the unverified drivers page to view selfie profiles and inspect submitted NBI and license credentials.',
                          icon: Icons.drive_eta_rounded,
                          accentColor: PassengerUi.secondary,
                          actionLabel: 'Open driver queue',
                          onTap: () => AdminNavigation.openUnverifiedDrivers(
                            context,
                            adminId: adminId,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 250,
                        child: AdminMetricCard(
                          label: 'Passenger Queue',
                          value: overview.unverifiedPassengers.toString(),
                          helper:
                              'Open the unverified passengers page to view selfie profiles and inspect submitted ID credentials.',
                          icon: Icons.person_search_rounded,
                          accentColor: PassengerUi.accentBlue,
                          actionLabel: 'Open passenger queue',
                          onTap: () => AdminNavigation.openUnverifiedPassengers(
                            context,
                            adminId: adminId,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Recent Booking Activity',
                    style: PassengerUi.sectionTitle,
                  ),
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminOverviewData {
  final int totalUsers;
  final int unverifiedDrivers;
  final int unverifiedPassengers;
  final int activeDrivers;
  final int studentPassengers;
  final int completedBookings;
  final int activeBookings;

  const _AdminOverviewData({
    required this.totalUsers,
    required this.unverifiedDrivers,
    required this.unverifiedPassengers,
    required this.activeDrivers,
    required this.studentPassengers,
    required this.completedBookings,
    required this.activeBookings,
  });

  factory _AdminOverviewData.fromData(
    List<AdminUserRecord> users,
    List<AdminBookingRecord> bookings,
  ) {
    final unverifiedDrivers = users
        .where((user) => user.isDriver && user.isPendingVerification)
        .length;
    final unverifiedPassengers = users
        .where((user) => user.isPassenger && user.isPendingVerification)
        .length;

    return _AdminOverviewData(
      totalUsers: users.length,
      unverifiedDrivers: unverifiedDrivers,
      unverifiedPassengers: unverifiedPassengers,
      activeDrivers: users
          .where((user) => user.isDriver && user.isVerified && user.isActive)
          .length,
      studentPassengers: users.where((user) => user.isStudentPassenger).length,
      completedBookings: bookings
          .where((booking) => booking.isCompleted)
          .length,
      activeBookings: bookings.where((booking) => booking.isActiveTrip).length,
    );
  }
}
