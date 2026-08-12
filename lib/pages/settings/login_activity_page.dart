import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/login_activity_entry.dart';
import '../../services/login_activity_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class LoginActivityPage extends StatelessWidget {
  final String? userId;
  final String? signedInEmail;
  final Stream<List<LoginActivityEntry>>? loginHistory;

  const LoginActivityPage({
    super.key,
    this.userId,
    this.signedInEmail,
    this.loginHistory,
  });

  @override
  Widget build(BuildContext context) {
    User? firebaseUser;
    if (userId == null || signedInEmail == null) {
      firebaseUser = FirebaseAuth.instance.currentUser;
    }

    final resolvedUserId = userId ?? firebaseUser?.uid ?? '';
    final resolvedEmail = signedInEmail ?? firebaseUser?.email;
    final activityStream =
        loginHistory ??
        LoginActivityService.instance.watchLoginHistory(userId: resolvedUserId);

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
        title: Text('Login Activity', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerPageHeader(
              title: 'Login Activity',
              subtitle: 'Review successful sign-ins to your SakayNow account.',
              icon: Icons.devices_rounded,
              accentColor: PassengerUi.accentBlue,
            ),
            const SizedBox(height: 16),
            PassengerSurfaceCard(
              padding: EdgeInsets.zero,
              child: _AccountRow(
                icon: Icons.alternate_email_rounded,
                label: 'Signed In As',
                value: _maskEmail(resolvedEmail),
              ),
            ),
            const SizedBox(height: 20),
            Text('Recent Logins', style: PassengerUi.sectionTitle),
            const SizedBox(height: 4),
            Text(
              'Your latest ${LoginActivityService.historyLimit} successful sign-ins are shown below.',
              style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<LoginActivityEntry>>(
              stream: activityStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _HistoryMessageCard(
                    icon: Icons.sync_problem_rounded,
                    title: 'Unable to load login history',
                    message:
                        'Check your connection, then reopen this page to try again.',
                  );
                }

                if (!snapshot.hasData) {
                  return const _HistoryLoadingCard();
                }

                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return const _HistoryMessageCard(
                    icon: Icons.history_rounded,
                    title: 'No saved login history yet',
                    message:
                        'Successful logins made after this update will appear here.',
                  );
                }

                return Column(
                  children: <Widget>[
                    for (var index = 0; index < entries.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _LoginHistoryCard(
                        entry: entries[index],
                        isMostRecent: index == 0,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginHistoryCard extends StatelessWidget {
  final LoginActivityEntry entry;
  final bool isMostRecent;

  const _LoginHistoryCard({required this.entry, required this.isMostRecent});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _platformIcon(entry.platform),
              color: PassengerUi.accentBlue,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.platformLabel,
                        style: PassengerUi.valueText.copyWith(fontSize: 14.5),
                      ),
                    ),
                    if (isMostRecent) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PassengerUi.successBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Most recent',
                          style: PassengerUi.bodyText.copyWith(
                            color: PassengerUi.successText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDateTime(entry.signedInAt),
                  style: PassengerUi.bodyText.copyWith(
                    color: PassengerUi.title,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.authMethodLabel,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLoadingCard extends StatelessWidget {
  const _HistoryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: PassengerUi.accentBlue,
            ),
          ),
          const SizedBox(width: 12),
          Text('Loading login history...', style: PassengerUi.bodyText),
        ],
      ),
    );
  }
}

class _HistoryMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HistoryMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: PassengerUi.body, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: PassengerUi.valueText),
                const SizedBox(height: 4),
                Text(message, style: PassengerUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 38 : 40,
            height: compact ? 38 : 40,
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: PassengerUi.accentBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.valueText.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Recording time...';
  }

  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $period';
}

String _maskEmail(String? email) {
  final normalized = email?.trim() ?? '';
  final atIndex = normalized.indexOf('@');
  if (normalized.isEmpty || atIndex <= 1) {
    return 'Not available';
  }

  final domain = normalized.substring(atIndex);
  final first = normalized.substring(0, 1);
  return '$first***$domain';
}

IconData _platformIcon(String platform) {
  return switch (platform) {
    'android' => Icons.android_rounded,
    'ios' => Icons.phone_iphone_rounded,
    'web' => Icons.language_rounded,
    'windows' || 'macos' || 'linux' => Icons.computer_rounded,
    _ => Icons.devices_other_rounded,
  };
}

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
