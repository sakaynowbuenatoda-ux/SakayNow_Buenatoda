import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminOperationsPage extends StatelessWidget {
  final String adminId;

  const AdminOperationsPage({super.key, required this.adminId});

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
                      'Bookings could not be loaded for operations: ${bookingsSnapshot.error}',
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
              final queuedCount = bookings
                  .where((booking) => booking.isQueued)
                  .length;
              final activeCount = bookings
                  .where((booking) => booking.isActiveTrip)
                  .length;
              final completedCount = bookings
                  .where((booking) => booking.isCompleted)
                  .length;
              final cancelledCount = bookings
                  .where((booking) => booking.isCancelled)
                  .length;
              final activeDrivers = users
                  .where(
                    (user) => user.isDriver && user.isVerified && user.isActive,
                  )
                  .length;
              final unverifiedDrivers = users
                  .where((user) => user.isDriver && user.isPendingVerification)
                  .length;
              final activePassengers = users
                  .where(
                    (user) =>
                        user.isPassenger && user.isVerified && user.isActive,
                  )
                  .length;
              final unverifiedPassengers = users
                  .where(
                    (user) => user.isPassenger && user.isPendingVerification,
                  )
                  .length;
              final cashlessTrips = bookings.where((booking) {
                final method =
                    booking.paymentMethod?.toLowerCase().trim() ?? '';
                return method.contains('gcash') || method.contains('maya');
              }).length;
              final fareTaggedTrips = bookings
                  .where((booking) => booking.fareLabel != null)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionIntro(title: 'Operations Monitor'),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Queue requests',
                          value: queuedCount.toString(),
                          helper: 'Pending or newly submitted',
                          icon: Icons.hourglass_top_rounded,
                          accentColor: PassengerUi.highlightAmber,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Active trips',
                          value: activeCount.toString(),
                          helper: 'Accepted and ongoing',
                          icon: Icons.local_shipping_rounded,
                          accentColor: PassengerUi.accentBlue,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Completed',
                          value: completedCount.toString(),
                          helper: 'Finished ride records',
                          icon: Icons.task_alt_rounded,
                          accentColor: PassengerUi.successText,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Cancelled',
                          value: cancelledCount.toString(),
                          helper: 'Trips needing follow-up',
                          icon: Icons.cancel_outlined,
                          accentColor: PassengerUi.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Trip Monitoring', style: PassengerUi.sectionTitle),
                  SizedBox(height: 6),
                  Text(
                    'These live cards help admins monitor ride request flow, dispatch health, and trip transparency.',
                    style: PassengerUi.bodyText,
                  ),
                  SizedBox(height: 12),
                  if (bookings.isEmpty)
                    AdminEmptyCollection(
                      icon: Icons.directions_car_filled_outlined,
                      title: 'No operational bookings yet',
                      description:
                          'Booking requests will populate here when passengers start using the ride system.',
                    )
                  else
                    ...bookings.take(6).map((booking) {
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
                  Text('User Operations', style: PassengerUi.sectionTitle),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Approved drivers',
                          value: activeDrivers.toString(),
                          helper: 'Verified and active',
                          icon: Icons.drive_eta_rounded,
                          accentColor: PassengerUi.accentBlue,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Active passengers',
                          value: activePassengers.toString(),
                          helper: 'Can request rides now',
                          icon: Icons.person_pin_circle_rounded,
                          accentColor: PassengerUi.secondary,
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: AdminMetricCard(
                          label: 'Unverified drivers',
                          value: unverifiedDrivers.toString(),
                          helper: 'Open the driver review queue',
                          icon: Icons.badge_outlined,
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
                          helper: 'Open the passenger review queue',
                          icon: Icons.verified_user_outlined,
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
                  SizedBox(height: 20),
                  Text(
                    'Fare and Payment Oversight',
                    style: PassengerUi.sectionTitle,
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'Transparency Snapshot',
                    icon: Icons.receipt_long_rounded,
                    accentColor: PassengerUi.primary,
                    description:
                        '$fareTaggedTrips booking record(s) currently expose a fare label, while $cashlessTrips booking record(s) already reference a cashless method such as GCash or Maya. This keeps the admin side aligned with the project objective around fair pricing and convenient payment support.',
                  ),
                  SizedBox(height: 12),
                  AdminInfoPanel(
                    title: 'LGU and Student Fare Readiness',
                    icon: Icons.school_rounded,
                    accentColor: PassengerUi.highlightAmber,
                    description:
                        'The admin view now includes a dedicated area to supervise fare visibility, student discount support, and cashless payment readiness even before the final fare engine is fully wired.',
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
