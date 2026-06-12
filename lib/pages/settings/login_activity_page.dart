import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class LoginActivityPage extends StatelessWidget {
  const LoginActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final createdAt = _formatDateTime(user?.metadata.creationTime);
    final lastSignIn = _formatDateTime(user?.metadata.lastSignInTime);

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
              subtitle: 'Basic account sign-in information.',
              icon: Icons.manage_history_rounded,
              accentColor: PassengerUi.accentBlue,
            ),
            const SizedBox(height: 16),
            PassengerSurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _ActivityRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Signed In As',
                    value: _maskEmail(user?.email),
                  ),
                  _DividerLine(),
                  _ActivityRow(
                    icon: Icons.event_available_outlined,
                    label: 'Account Created',
                    value: createdAt,
                  ),
                  _DividerLine(),
                  _ActivityRow(
                    icon: Icons.login_rounded,
                    label: 'Last Sign-In',
                    value: lastSignIn,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Not available';
    }

    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${_months[local.month - 1]} ${local.day}, ${local.year}, $hour:$minute $period';
  }

  static String _maskEmail(String? email) {
    final normalized = email?.trim() ?? '';
    final atIndex = normalized.indexOf('@');
    if (normalized.isEmpty || atIndex <= 1) {
      return 'Not available';
    }

    final domain = normalized.substring(atIndex);
    final first = normalized.substring(0, 1);
    return '$first***$domain';
  }

  static const List<String> _months = <String>[
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
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ActivityRow({
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: PassengerUi.border),
    );
  }
}
