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
      appBar: AppBar(
        backgroundColor: AdminUi.surface,
        surfaceTintColor: AdminUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: AdminUi.title),
        ),
        title: Text('Admin Action Logs', style: AdminUi.cardTitle),
      ),
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
                      'Review admin account, verification, restriction, restoration, and fare-setting activity.',
                  count: logs.length.toString(),
                  countLabel: 'logged actions',
                  icon: Icons.history_rounded,
                  accentColor: AdminUi.accentBlue,
                ),
                const SizedBox(height: 16),
                if (logs.isEmpty)
                  const AdminEmptyCollection(
                    icon: Icons.history_rounded,
                    title: 'No admin actions logged yet',
                    description:
                        'Admin actions will appear here after account reviews, restores, fare updates, or admin account creation.',
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AdminUi.soft(_accentColor, alpha: 0.14),
              borderRadius: AdminUi.radius,
              border: Border.all(color: _accentColor.withValues(alpha: 0.12)),
            ),
            child: Icon(_icon, color: _accentColor, size: 21),
          ),
          const SizedBox(width: 13),
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

  IconData get _icon {
    switch (log.action) {
      case 'admin_account_created':
        return Icons.admin_panel_settings_rounded;
      case 'admin_account_deactivated':
        return Icons.no_accounts_rounded;
      case 'admin_account_restored':
        return Icons.restore_rounded;
      case 'fare_settings_updated':
        return Icons.tune_rounded;
      case 'user_restricted':
        return Icons.block_rounded;
      case 'user_restored':
      case 'deactivated_user_restored':
        return Icons.restart_alt_rounded;
      case 'user_approved':
        return Icons.verified_user_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color get _accentColor {
    switch (log.action) {
      case 'user_restricted':
      case 'admin_account_deactivated':
        return AdminUi.highlightAmber;
      case 'user_approved':
      case 'user_restored':
      case 'deactivated_user_restored':
      case 'admin_account_restored':
        return AdminUi.successText;
      case 'fare_settings_updated':
        return AdminUi.accentBlue;
      default:
        return AdminUi.primary;
    }
  }
}
