import 'package:flutter/material.dart';

import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminActionLogsPage extends StatelessWidget {
  const AdminActionLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: const AdminDetailAppBar(title: 'Admin Action Logs'),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.listContentWidth,
        child: StreamBuilder<List<AdminActionLogRecord>>(
          stream: AdminService.watchAdminLogs(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminErrorCard(
                message: 'Unable to load admin logs. Please try again.',
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final logs = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminCountPageHeader(
                  title: 'Admin Action Logs',
                  subtitle:
                      'Review account, verification, report moderation, restoration, and fare-setting activity.',
                  count: logs.length.toString(),
                  countLabel: 'logged actions',
                  accentColor: AdminUi.accentBlue,
                ),
                const SizedBox(height: 16),
                if (logs.isEmpty)
                  const AdminEmptyCollection(
                    icon: Icons.history_rounded,
                    title: 'No admin actions logged yet',
                    description:
                        'Admin actions will appear here after account reviews, report moderation, restores, fare updates, or admin account creation.',
                  )
                else
                  ...logs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdminActionLogCard(log: log),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminActionLogCard extends StatelessWidget {
  final AdminActionLogRecord log;

  const _AdminActionLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(log.actionLabel, style: AdminUi.cardTitle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatDateTime(log.createdAt),
                      textAlign: TextAlign.end,
                      style: AdminUi.labelText.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(log.summary, style: AdminUi.bodyText),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminStatusChip(
                      label: 'By ${log.adminName}',
                      textColor: AdminUi.accentBlue,
                      backgroundColor: AdminUi.blueSoft,
                    ),
                    AdminStatusChip(
                      label: log.targetLabel,
                      textColor: AdminUi.body,
                      backgroundColor: AdminUi.mutedSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
