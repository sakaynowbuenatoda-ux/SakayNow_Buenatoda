import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum AdminUnverifiedQueueType { drivers, passengers }

class AdminUnverifiedUsersPage extends StatelessWidget {
  final String adminId;
  final AdminUnverifiedQueueType queueType;

  const AdminUnverifiedUsersPage({
    super.key,
    required this.adminId,
    required this.queueType,
  });

  bool get _showDrivers => queueType == AdminUnverifiedQueueType.drivers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text(_pageTitle, style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: StreamBuilder<List<AdminUserRecord>>(
          stream: AdminService.watchUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminErrorCard(
                message: 'Unable to load $_collectionLabel: ${snapshot.error}',
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final filteredUsers = snapshot.data!
                .where((user) => user.isPendingVerification)
                .where(
                  (user) => _showDrivers ? user.isDriver : user.isPassenger,
                )
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PassengerPageHeader(
                  title: _pageTitle,
                  subtitle: _pageSubtitle,
                  icon: _showDrivers
                      ? Icons.two_wheeler_rounded
                      : Icons.person_outline_rounded,
                  accentColor: _showDrivers
                      ? PassengerUi.secondary
                      : PassengerUi.accentBlue,
                ),
                SizedBox(height: 16),
                AdminMetricCard(
                  label: _metricLabel,
                  value: filteredUsers.length.toString(),
                  helper: _metricHelper,
                  icon: _showDrivers
                      ? Icons.badge_rounded
                      : Icons.verified_user_outlined,
                  accentColor: _showDrivers
                      ? PassengerUi.secondary
                      : PassengerUi.accentBlue,
                ),
                SizedBox(height: 18),
                Text(_sectionTitle, style: PassengerUi.sectionTitle),
                SizedBox(height: 6),
                Text(_sectionSubtitle, style: PassengerUi.bodyText),
                SizedBox(height: 12),
                if (filteredUsers.isEmpty)
                  AdminEmptyCollection(
                    icon: _showDrivers
                        ? Icons.drive_eta_outlined
                        : Icons.person_search_outlined,
                    title: _emptyTitle,
                    description: _emptyDescription,
                  )
                else
                  ...filteredUsers.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminQueueUserTile(
                        user: user,
                        onView: () => AdminNavigation.openUserReview(
                          context,
                          adminId: adminId,
                          userId: user.userId,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String get _pageTitle =>
      _showDrivers ? 'Unverified Drivers' : 'Unverified Passengers';

  String get _pageSubtitle => _showDrivers
      ? 'Review drivers who uploaded a selfie, NBI clearance, and license before turning is_verified to true.'
      : 'Review passengers who uploaded a selfie and ID before turning is_verified to true.';

  String get _collectionLabel =>
      _showDrivers ? 'unverified drivers' : 'unverified passengers';

  String get _metricLabel =>
      _showDrivers ? 'Drivers Waiting' : 'Passengers Waiting';

  String get _metricHelper => _showDrivers
      ? 'Driver accounts pending credential review.'
      : 'Passenger accounts pending identity review.';

  String get _sectionTitle => _showDrivers ? 'Driver Queue' : 'Passenger Queue';

  String get _sectionSubtitle => _showDrivers
      ? 'Each list item shows the submitted selfie profile and opens a full driver review page with selfie, NBI clearance, and license.'
      : 'Each list item shows the submitted selfie profile and opens a full passenger review page with selfie and ID.';

  String get _emptyTitle => _showDrivers
      ? 'No unverified drivers waiting'
      : 'No unverified passengers waiting';

  String get _emptyDescription => _showDrivers
      ? 'New driver signups will appear here when they are still waiting for admin verification.'
      : 'New passenger signups will appear here when they are still waiting for admin verification.';
}
