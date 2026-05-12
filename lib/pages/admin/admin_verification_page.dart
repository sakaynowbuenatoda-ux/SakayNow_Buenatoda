import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminVerificationPage extends StatelessWidget {
  final String adminId;

  const AdminVerificationPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load verification queue: ${snapshot.error}',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;
          final pendingUsers = users
              .where((user) => user.isPendingVerification)
              .toList(growable: false);
          final restrictedUsers = users
              .where((user) => !user.isAdmin && user.isBanned)
              .toList(growable: false);
          final pendingDrivers = pendingUsers
              .where((user) => user.isDriver)
              .length;
          final pendingPassengers = pendingUsers
              .where((user) => user.isPassenger)
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionIntro(
                title: 'Verification Center',
                subtitle:
                    'Open the role-based queues below to review unverified drivers and passengers, inspect their uploaded credentials, and update Firestore once each account is approved.',
              ),
              SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = _metricCardWidth(constraints.maxWidth);

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: AdminMetricCard(
                          label: 'Unverified drivers',
                          value: pendingDrivers.toString(),
                          helper:
                              'Open the driver page to inspect selfie, NBI clearance, and license uploads.',
                          icon: Icons.two_wheeler_rounded,
                          accentColor: PassengerUi.secondary,
                          actionLabel: 'Open driver page',
                          onTap: () => AdminNavigation.openUnverifiedDrivers(
                            context,
                            adminId: adminId,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: AdminMetricCard(
                          label: 'Unverified passengers',
                          value: pendingPassengers.toString(),
                          helper:
                              'Open the passenger page to inspect selfie and ID uploads.',
                          icon: Icons.person_outline_rounded,
                          accentColor: PassengerUi.accentBlue,
                          actionLabel: 'Open passenger page',
                          onTap: () => AdminNavigation.openUnverifiedPassengers(
                            context,
                            adminId: adminId,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: AdminMetricCard(
                          label: 'Pending users',
                          value: pendingUsers.length.toString(),
                          helper:
                              'Combined total of unverified drivers and passengers.',
                          icon: Icons.fact_check_rounded,
                          accentColor: PassengerUi.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 18),
              Text('Queue Access', style: PassengerUi.sectionTitle),
              SizedBox(height: 6),
              Text(
                pendingUsers.isEmpty
                    ? 'There are currently no unverified passenger or driver accounts waiting for review.'
                    : '${pendingUsers.length} account(s) are waiting for admin verification. Use the driver and passenger cards below to open the correct review list.',
                style: PassengerUi.bodyText,
              ),
              SizedBox(height: 12),
              if (pendingUsers.isEmpty)
                const AdminEmptyCollection(
                  icon: Icons.verified_user_outlined,
                  title: 'No unverified users waiting',
                  description:
                      'New passenger and driver signups will appear here until an admin verifies them.',
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 250,
                      child: AdminMetricCard(
                        label: 'Driver Review List',
                        value: pendingDrivers.toString(),
                        helper:
                            'See every unverified driver in one list with selfie profile and a direct view button.',
                        icon: Icons.drive_eta_rounded,
                        accentColor: PassengerUi.secondary,
                        actionLabel: 'Open driver page',
                        onTap: () => AdminNavigation.openUnverifiedDrivers(
                          context,
                          adminId: adminId,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: AdminMetricCard(
                        label: 'Passenger Review List',
                        value: pendingPassengers.toString(),
                        helper:
                            'See every unverified passenger in one list with selfie profile and a direct view button.',
                        icon: Icons.person_search_rounded,
                        accentColor: PassengerUi.accentBlue,
                        actionLabel: 'Open passenger page',
                        onTap: () => AdminNavigation.openUnverifiedPassengers(
                          context,
                          adminId: adminId,
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 18),
              Text('Restricted Accounts', style: PassengerUi.sectionTitle),
              SizedBox(height: 6),
              Text(
                'Restore access when a restricted account has already been reviewed and should be active again.',
                style: PassengerUi.bodyText,
              ),
              SizedBox(height: 12),
              if (restrictedUsers.isEmpty)
                const AdminEmptyCollection(
                  icon: Icons.shield_outlined,
                  title: 'No restricted accounts',
                  description:
                      'Accounts marked as restricted will appear here for follow-up review.',
                )
              else
                ...restrictedUsers.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AdminUserCard(
                      user: user,
                      actions: [
                        AdminActionButton(
                          label: 'Restore Access',
                          icon: Icons.restart_alt_rounded,
                          backgroundColor: PassengerUi.successBackground,
                          foregroundColor: PassengerUi.successText,
                          onPressed: () => _runAction(
                            context,
                            action: () => AdminService.restoreUser(
                              userId: user.userId,
                              adminId: adminId,
                            ),
                            successMessage: '${user.fullName} is active again.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _metricCardWidth(double maxWidth) {
    if (maxWidth < 640) {
      return maxWidth;
    }

    if (maxWidth < 980) {
      return (maxWidth - 12) / 2;
    }

    return (maxWidth - 24) / 3;
  }

  Future<void> _runAction(
    BuildContext context, {
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    try {
      await action();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    }
  }
}
