import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../driver/driver_payout_accounts_page.dart';
import '../passenger/passenger_payment_methods_page.dart';
import '../profile/profile_details.dart';
import 'app_preferences_page.dart';
import 'change_password_page.dart';
import 'developers.dart';
import 'help_and_support.dart';
import 'notification_settings_page.dart';
import 'privacy_policy.dart';
import 'settings_placeholder_page.dart';
import 'terms_and_conditions.dart';
import 'version_page.dart';
import 'widgets/settings_section_card.dart';

class SettingsPage extends StatelessWidget {
  final String? userId;
  final String role;
  final bool isVerified;
  final String passengerType;

  const SettingsPage({
    super.key,
    this.userId,
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
    final isDriver = normalizedRole == 'driver';
    final isPassenger =
        normalizedRole == 'passenger' ||
        normalizedRole == 'regular' ||
        normalizedRole == 'student';
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    final canOpenProfile = currentUserId != null && currentUserId.isNotEmpty;

    final accountItems = <SettingsTileData>[
      SettingsTileData(
        title: 'Profile Information',
        subtitle: 'Review your personal account details.',
        icon: Icons.person_outline_rounded,
        accentColor: PassengerUi.primary,
        isEnabled: canOpenProfile,
        statusLabel: !isAdmin && isVerified ? 'Verified' : null,
        onTap: canOpenProfile
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileDetailsLoaderPage(userId: currentUserId),
                ),
              )
            : null,
      ),
      SettingsTileData(
        title: 'Change Password',
        subtitle: 'Manage login credentials and password recovery options.',
        icon: Icons.lock_outline_rounded,
        accentColor: PassengerUi.accentBlue,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
      ),
      if ((isDriver || isPassenger) && canOpenProfile)
        SettingsTileData(
          title: isDriver ? 'Payout Account' : 'Payment Methods',
          subtitle: isDriver
              ? 'Add or update where you receive online ride payments.'
              : 'Manage Cash, GCash, Maya, and card payment options.',
          icon: isDriver
              ? Icons.account_balance_rounded
              : Icons.account_balance_wallet_rounded,
          accentColor: PassengerUi.accentBlue,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => isDriver
                  ? DriverPayoutAccountsPage(driverId: currentUserId)
                  : PassengerPaymentMethodsPage(userId: currentUserId),
            ),
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationSettingsPage(userId: currentUserId),
          ),
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
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DevelopersPage())),
      ),
      SettingsTileData(
        title: 'Help and Support',
        subtitle: 'Get assistance for account, ride, or app-related concerns.',
        icon: Icons.help_outline_rounded,
        accentColor: PassengerUi.secondary,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HelpAndSupportPage())),
      ),
      SettingsTileData(
        title: 'Terms and Conditions',
        subtitle: 'Review your rights, responsibilities, and service rules.',
        icon: Icons.gavel_rounded,
        accentColor: PassengerUi.primary,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TermsAndConditionsPage()),
        ),
      ),
      SettingsTileData(
        title: 'Privacy Policy',
        subtitle: 'Understand how your personal data is collected and handled.',
        icon: Icons.privacy_tip_outlined,
        accentColor: PassengerUi.highlightAmber,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
      ),
      SettingsTileData(
        title: 'Version',
        subtitle: 'View the current app version and release information.',
        icon: Icons.info_outline_rounded,
        accentColor: PassengerUi.body,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const VersionPage())),
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
}
