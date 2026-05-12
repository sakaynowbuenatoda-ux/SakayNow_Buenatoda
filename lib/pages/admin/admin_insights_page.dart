import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminInsightsPage extends StatelessWidget {
  final String adminId;

  const AdminInsightsPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
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
              final completedTrips = bookings
                  .where((booking) => booking.isCompleted)
                  .length;
              final activeTrips = bookings
                  .where((booking) => booking.isActiveTrip)
                  .length;
              final activeDrivers = users
                  .where(
                    (user) => user.isDriver && user.isActive && user.isVerified,
                  )
                  .length;
              final tripsPerDriver = activeDrivers == 0
                  ? 0
                  : (activeTrips / activeDrivers).ceil();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionIntro(title: 'Insights and Quality'),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Verified drivers',
                          value: verifiedDrivers.toString(),
                          helper: 'Cleared for dispatch',
                          icon: Icons.badge_rounded,
                          accentColor: PassengerUi.primary,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Verified passengers',
                          value: verifiedPassengers.toString(),
                          helper: 'Approved for bookings',
                          icon: Icons.verified_user_rounded,
                          accentColor: PassengerUi.secondary,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Unverified drivers',
                          value: unverifiedDrivers.toString(),
                          helper: 'Driver credentials awaiting review',
                          icon: Icons.two_wheeler_rounded,
                          accentColor: PassengerUi.highlightAmber,
                          actionLabel: 'Open driver queue',
                          onTap: () => AdminNavigation.openUnverifiedDrivers(
                            context,
                            adminId: adminId,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Unverified passengers',
                          value: unverifiedPassengers.toString(),
                          helper: 'Passenger IDs awaiting review',
                          icon: Icons.person_search_rounded,
                          accentColor: PassengerUi.accentBlue,
                          actionLabel: 'Open passenger queue',
                          onTap: () => AdminNavigation.openUnverifiedPassengers(
                            context,
                            adminId: adminId,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Restricted users',
                          value: restrictedAccounts.toString(),
                          helper: 'Safety actions applied',
                          icon: Icons.gpp_bad_rounded,
                          accentColor: PassengerUi.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  AdminInfoPanel(
                    title: 'Rating and Review System',
                    icon: Icons.star_half_rounded,
                    accentColor: PassengerUi.highlightAmber,
                    description:
                        'The admin side now includes a clear quality-monitoring space for future driver ratings, reviews, rankings, and passenger feedback analytics. As backend review writes are added, this section can directly surface service quality trends without redesigning the dashboard.',
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Reports and Incident Handling',
                    icon: Icons.report_gmailerrorred_rounded,
                    accentColor: PassengerUi.primary,
                    description:
                        'A dedicated monitoring layer is now visible for report handling and moderation. This keeps the admin workflow aligned with the study requirement for accountability, security, and issue escalation.',
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Service Load Snapshot',
                    icon: Icons.analytics_outlined,
                    accentColor: PassengerUi.accentBlue,
                    description:
                        '$completedTrips completed trip(s) and $activeTrips active trip(s) are currently visible. Based on approved active drivers, the live operational load is about $tripsPerDriver trip slot(s) per driver.',
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Overall System Performance',
                    icon: Icons.monitor_heart_outlined,
                    accentColor: PassengerUi.accentBlue,
                    description:
                        'This panel now gives admins a single mobile-friendly place to watch users, trip flow, verification status, payments, and operational health in line with the intended admin dashboard scope of SakayNow Buenatoda.',
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
