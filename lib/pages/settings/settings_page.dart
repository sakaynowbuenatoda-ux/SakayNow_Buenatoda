import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'app_preferences_page.dart';
import 'settings_placeholder_page.dart';
import 'widgets/settings_section_card.dart';

class SettingsPage extends StatelessWidget {
  final String role;
  final bool isVerified;
  final String passengerType;

  const SettingsPage({
    super.key,
    required this.role,
    this.isVerified = false,
    this.passengerType = 'regular',
  });

  void _openPlaceholder(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPlaceholderPage(
          title: title,
          description: description,
          icon: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedRole = role.trim().toLowerCase();
    final isAdmin = normalizedRole == 'admin';
    final canEditProfile = isAdmin || isVerified;
    final isStudentPassenger =
        normalizedRole == 'passenger' &&
        passengerType.trim().toLowerCase() == 'student';

    final accountItems = <SettingsTileData>[
      SettingsTileData(
        title: 'Profile Information',
        subtitle: canEditProfile
            ? 'Review and update your account details and public profile.'
            : 'Profile editing unlocks after your account is verified by admin.',
        icon: Icons.person_outline_rounded,
        accentColor: PassengerUi.primary,
        isEnabled: canEditProfile,
        statusLabel: canEditProfile
            ? (!isAdmin && isVerified ? 'Verified' : null)
            : 'Locked',
        onTap: canEditProfile
            ? () => _openPlaceholder(
                context,
                title: 'Profile Information',
                description:
                    'This page will let users manage their profile information and account data.',
                icon: Icons.person_outline_rounded,
              )
            : null,
      ),
      SettingsTileData(
        title: 'Change Password',
        subtitle: 'Manage login credentials and password recovery options.',
        icon: Icons.lock_outline_rounded,
        accentColor: PassengerUi.accentBlue,
        onTap: () => _openPlaceholder(
          context,
          title: 'Change Password',
          description:
              'This section will handle secure password updates and credential management.',
          icon: Icons.lock_outline_rounded,
        ),
      ),
    ];

    final appItems = <SettingsTileData>[
      SettingsTileData(
        title: 'Notifications',
        subtitle:
            'Control ride updates, alerts, and account-related reminders.',
        icon: Icons.notifications_none_rounded,
        accentColor: PassengerUi.secondary,
        onTap: () => _openPlaceholder(
          context,
          title: 'Notifications',
          description:
              'Notification preferences and alert categories will appear here.',
          icon: Icons.notifications_none_rounded,
        ),
      ),
      SettingsTileData(
        title: 'App Preferences',
        subtitle:
            'Customize app behavior, convenience options, and display choices.',
        icon: Icons.tune_rounded,
        accentColor: PassengerUi.highlightAmber,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => AppPreferencesPage())),
      ),
    ];

    final privacyItems = <SettingsTileData>[
      SettingsTileData(
        title: 'Privacy and Security',
        subtitle:
            'Review protection features, permissions, and account safeguards.',
        icon: Icons.verified_user_outlined,
        accentColor: PassengerUi.primary,
        onTap: () => _openPlaceholder(
          context,
          title: 'Privacy and Security',
          description:
              'Privacy controls, permissions, and security actions will be available here.',
          icon: Icons.verified_user_outlined,
        ),
      ),
    ];

    final miscItems = <SettingsTileData>[
      SettingsTileData(
        title: 'Developers',
        subtitle: 'See project and development information.',
        icon: Icons.code_rounded,
        accentColor: PassengerUi.accentBlue,
        onTap: () => _openPlaceholder(
          context,
          title: 'Developers',
          description:
              'Developer information and team details will be shown here.',
          icon: Icons.code_rounded,
        ),
      ),
      SettingsTileData(
        title: 'Help and Support',
        subtitle: 'Get assistance for account, ride, or app-related concerns.',
        icon: Icons.help_outline_rounded,
        accentColor: PassengerUi.secondary,
        onTap: () => _openPlaceholder(
          context,
          title: 'Help and Support',
          description:
              'Support resources, FAQs, and contact options will appear here.',
          icon: Icons.help_outline_rounded,
        ),
      ),
      SettingsTileData(
        title: 'Terms and Conditions',
        subtitle: 'Review your rights, responsibilities, and service rules.',
        icon: Icons.gavel_rounded,
        accentColor: PassengerUi.primary,
        onTap: () => _openPlaceholder(
          context,
          title: 'Terms and Conditions',
          description:
              'The full terms and conditions page can be expanded here later.',
          icon: Icons.gavel_rounded,
        ),
      ),
      SettingsTileData(
        title: 'Privacy Policy',
        subtitle: 'Understand how your personal data is collected and handled.',
        icon: Icons.privacy_tip_outlined,
        accentColor: PassengerUi.highlightAmber,
        onTap: () => _openPlaceholder(
          context,
          title: 'Privacy Policy',
          description: 'The full privacy policy page can be added here later.',
          icon: Icons.privacy_tip_outlined,
        ),
      ),
      SettingsTileData(
        title: 'Version',
        subtitle: 'View the current app version and release information.',
        icon: Icons.info_outline_rounded,
        accentColor: PassengerUi.body,
        onTap: () => _openPlaceholder(
          context,
          title: 'Version',
          description:
              'App version details and release notes can be shown here.',
          icon: Icons.info_outline_rounded,
        ),
      ),
    ];

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
        title: Text('Settings', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerPageHeader(
              title: 'Settings',
              subtitle:
                  'Personalize your account, alerts, security, and app display.',
              icon: Icons.tune_rounded,
              accentColor: PassengerUi.primary,
            ),
            SizedBox(height: 16),
            if (!isAdmin) ...[
              PassengerSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Account Verification', style: PassengerUi.cardTitle),
                    SizedBox(height: 10),
                    PassengerStatusChip(
                      label: isVerified
                          ? 'Verified account'
                          : 'Pending verification',
                      textColor: isVerified
                          ? PassengerUi.successText
                          : PassengerUi.primary,
                      backgroundColor: isVerified
                          ? PassengerUi.successBackground
                          : PassengerUi.dangerSoft,
                    ),
                    SizedBox(height: 12),
                    Text(
                      _verificationMessage(
                        isVerified: isVerified,
                        isStudentPassenger: isStudentPassenger,
                      ),
                      style: PassengerUi.bodyText,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
            ],
            SettingsSectionCard(title: 'Account Settings', items: accountItems),
            SizedBox(height: 14),
            SettingsSectionCard(title: 'App Settings', items: appItems),
            SizedBox(height: 14),
            SettingsSectionCard(
              title: 'Privacy and Security',
              items: privacyItems,
            ),
            SizedBox(height: 14),
            SettingsSectionCard(items: miscItems),
          ],
        ),
      ),
    );
  }

  String _verificationMessage({
    required bool isVerified,
    required bool isStudentPassenger,
  }) {
    if (isVerified && isStudentPassenger) {
      return 'Your account is verified. Profile editing is available and your student discount can now be honored in supported ride flows.';
    }

    if (isVerified) {
      return 'Your account is verified and profile editing is now available.';
    }

    if (isStudentPassenger) {
      return 'You can continue using the app, but profile editing and the student discount stay locked until an admin verifies your submitted documents.';
    }

    return 'You can continue using the app, but profile editing stays locked until an admin verifies your account.';
  }
}
