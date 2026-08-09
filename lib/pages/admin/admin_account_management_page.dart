import 'package:flutter/material.dart';

import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminAccountManagementPage extends StatelessWidget {
  final String adminId;

  const AdminAccountManagementPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load account management. Please try again.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;
          final registeredUsers = users
              .where((user) => user.isPassengerOrDriver)
              .length;
          final pendingUsers = users
              .where((user) => user.needsApproval)
              .toList(growable: false);
          final restrictedUsers = users
              .where((user) => !user.isAdmin && user.isBanned)
              .toList(growable: false);
          final deactivatedUsers = users
              .where((user) => user.isDeactivated && !user.isDeleted)
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
                title: 'Account Management',
                subtitle:
                    'Review pending verification and driver renewals, restore deactivated users within 60 days, and follow up on restricted accounts.',
              ),
              SizedBox(height: 16),
              _AccountTopGrid(
                metrics: _AccountMetricsPanel(
                  registeredUsers: registeredUsers,
                  pendingDrivers: pendingDrivers,
                  pendingPassengers: pendingPassengers,
                  deactivatedUsers: deactivatedUsers.length,
                  restrictedUsers: restrictedUsers.length,
                  adminId: adminId,
                ),
                policy: AdminInfoPanel(
                  title: 'Retention Policy',
                  description:
                      'Deactivated accounts can be restored by an admin within 60 days. After that, personal account identity is anonymized or deleted, while booking and transaction records may be retained for up to 5 years.',
                ),
              ),
              SizedBox(height: 18),
              _AccountBottomGrid(
                verification: _VerificationQueuesPanel(
                  pendingUsers: pendingUsers.length,
                  pendingDrivers: pendingDrivers,
                  pendingPassengers: pendingPassengers,
                  adminId: adminId,
                ),
                restricted: _RestrictedReviewPanel(
                  restrictedUsers: restrictedUsers.length,
                  adminId: adminId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountTopGrid extends StatelessWidget {
  final Widget metrics;
  final Widget policy;

  const _AccountTopGrid({required this.metrics, required this.policy});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final twoColumns = constraints.maxWidth >= 980;
        final leftWidth = twoColumns
            ? ((constraints.maxWidth - spacing) * 0.62)
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
            SizedBox(width: rightWidth, child: policy),
          ],
        );
      },
    );
  }
}

class _AccountBottomGrid extends StatelessWidget {
  final Widget verification;
  final Widget restricted;

  const _AccountBottomGrid({
    required this.verification,
    required this.restricted,
  });

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
            SizedBox(width: itemWidth, child: verification),
            SizedBox(width: itemWidth, child: restricted),
          ],
        );
      },
    );
  }
}

class _AccountMetricsPanel extends StatelessWidget {
  final int registeredUsers;
  final int pendingDrivers;
  final int pendingPassengers;
  final int deactivatedUsers;
  final int restrictedUsers;
  final String adminId;

  const _AccountMetricsPanel({
    required this.registeredUsers,
    required this.pendingDrivers,
    required this.pendingPassengers,
    required this.deactivatedUsers,
    required this.restrictedUsers,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return _AccountSurfacePanel(
      title: 'Account Metrics',
      subtitle: 'Tap a card to open the related review page.',
      accentColor: AdminUi.accentBlue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final twoColumns = constraints.maxWidth >= 560;
          final cardWidth = twoColumns
              ? (constraints.maxWidth - spacing) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Registered users',
                  value: registeredUsers.toString(),
                  helper: 'Passengers and drivers',
                  icon: Icons.groups_rounded,
                  accentColor: AdminUi.primary,
                  onTap: () => AdminNavigation.openRegisteredUsers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Unverified drivers',
                  value: pendingDrivers.toString(),
                  helper: 'Inspect selfie, NBI clearance, and license uploads.',
                  icon: Icons.two_wheeler_rounded,
                  accentColor: AdminUi.secondary,
                  onTap: () => AdminNavigation.openUnverifiedDrivers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Unverified passengers',
                  value: pendingPassengers.toString(),
                  helper: 'Inspect selfie and ID uploads.',
                  icon: Icons.person_outline_rounded,
                  accentColor: AdminUi.accentBlue,
                  onTap: () => AdminNavigation.openUnverifiedPassengers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Deactivated users',
                  value: deactivatedUsers.toString(),
                  helper: 'Restore before the 60-day deletion window ends.',
                  icon: Icons.no_accounts_rounded,
                  accentColor: AdminUi.primary,
                  onTap: () => AdminNavigation.openDeactivatedUsers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Restricted accounts',
                  value: restrictedUsers.toString(),
                  helper: 'Accounts blocked by admin review decisions.',
                  icon: Icons.block_rounded,
                  accentColor: AdminUi.highlightAmber,
                  onTap: () => AdminNavigation.openRestrictedUsers(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VerificationQueuesPanel extends StatelessWidget {
  final int pendingUsers;
  final int pendingDrivers;
  final int pendingPassengers;
  final String adminId;

  const _VerificationQueuesPanel({
    required this.pendingUsers,
    required this.pendingDrivers,
    required this.pendingPassengers,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return _AccountSurfacePanel(
      title: 'Verification Queues',
      subtitle: pendingUsers == 0
          ? 'There are currently no accounts waiting for review.'
          : '$pendingUsers account(s) are waiting for admin verification.',
      accentColor: AdminUi.secondary,
      child: pendingUsers == 0
          ? const AdminEmptyCollection(
              icon: Icons.verified_user_outlined,
              title: 'No unverified users waiting',
              description:
                  'New passenger and driver signups will appear here until an admin verifies them.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final twoColumns = constraints.maxWidth >= 520;
                final width = twoColumns
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _MetricFrame(
                      width: width,
                      child: AdminMetricCard(
                        label: 'Driver Review List',
                        value: pendingDrivers.toString(),
                        helper: 'Open every unverified driver profile.',
                        icon: Icons.drive_eta_rounded,
                        accentColor: AdminUi.secondary,
                        onTap: () => AdminNavigation.openUnverifiedDrivers(
                          context,
                          adminId: adminId,
                        ),
                      ),
                    ),
                    _MetricFrame(
                      width: width,
                      child: AdminMetricCard(
                        label: 'Passenger Review List',
                        value: pendingPassengers.toString(),
                        helper: 'Open every unverified passenger profile.',
                        icon: Icons.person_search_rounded,
                        accentColor: AdminUi.accentBlue,
                        onTap: () => AdminNavigation.openUnverifiedPassengers(
                          context,
                          adminId: adminId,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _RestrictedReviewPanel extends StatelessWidget {
  final int restrictedUsers;
  final String adminId;

  const _RestrictedReviewPanel({
    required this.restrictedUsers,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return _AccountSurfacePanel(
      title: 'Restricted Account Review',
      subtitle: restrictedUsers == 0
          ? 'There are no restricted accounts that need follow-up right now.'
          : '$restrictedUsers restricted account(s) need follow-up.',
      accentColor: AdminUi.highlightAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            restrictedUsers == 0
                ? 'Accounts blocked by admin decisions will appear here for follow-up and restoration.'
                : 'Open the restricted users page to search, sort, inspect, and restore access after review.',
            style: AdminUi.bodyText,
          ),
          if (restrictedUsers > 0) ...[
            SizedBox(height: 14),
            AdminActionButton(
              label: 'Open Restricted Users',
              icon: Icons.arrow_forward_rounded,
              backgroundColor: AdminUi.warningSoft,
              foregroundColor: AdminUi.highlightAmber,
              onPressed: () => AdminNavigation.openRestrictedUsers(
                context,
                adminId: adminId,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountSurfacePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _AccountSurfacePanel({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final background = Color.lerp(
      AdminUi.surface,
      accentColor,
      AdminUi.isDarkMode ? 0.10 : 0.035,
    );

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

class _MetricFrame extends StatelessWidget {
  final double width;
  final Widget child;

  const _MetricFrame({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: 132, child: child);
  }
}
