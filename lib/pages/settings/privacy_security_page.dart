import 'package:flutter/material.dart';

import '../../core/preferences/privacy_security_preferences_controller.dart';
import '../../services/device_auth_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'login_activity_page.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final PrivacySecurityPreferencesController _controller =
      PrivacySecurityPreferencesController.instance;
  final DeviceAuthService _deviceAuthService = DeviceAuthService();
  bool _isAuthenticatingAppLock = false;

  static const List<int> _autoLogoutOptions = <int>[15, 30, 60];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
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
        title: Text('Privacy and Security', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PrivacyActionCard(
              title: 'Login Activity',
              subtitle: 'Review the history of successful account logins.',
              icon: Icons.manage_history_rounded,
              actionLabel: 'View',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginActivityPage()),
              ),
            ),
            const SizedBox(height: 14),
            _PrivacyToggleCard(
              title: 'Auto Logout',
              subtitle: 'Sign out after inactive use on this device.',
              icon: Icons.timer_outlined,
              accentColor: PassengerUi.accentBlue,
              value: _controller.autoLogoutEnabled,
              onChanged: (value) {
                _controller.setAutoLogoutEnabled(value);
                _showSavedMessage();
              },
              footer: _AutoLogoutOptions(
                selectedMinutes: _controller.autoLogoutMinutes,
                options: _autoLogoutOptions,
                onChanged: (minutes) {
                  _controller.setAutoLogoutMinutes(minutes);
                  _showSavedMessage();
                },
              ),
            ),
            const SizedBox(height: 14),
            _PrivacyToggleCard(
              title: 'App Lock',
              subtitle:
                  'Require biometrics or your device PIN on a fresh app start.',
              icon: Icons.phonelink_lock_outlined,
              accentColor: PassengerUi.secondary,
              value: _controller.appLockEnabled,
              isSaving: _isAuthenticatingAppLock,
              onChanged: _handleAppLockChanged,
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Privacy setting saved on this device.')),
      );
  }

  Future<void> _handleAppLockChanged(bool value) async {
    if (!value) {
      await _controller.setAppLockEnabled(false);
      _showSavedMessage();
      return;
    }

    setState(() => _isAuthenticatingAppLock = true);

    final result = await _deviceAuthService.authenticate(
      reason: 'Confirm your device lock to enable SakayNow App Lock.',
    );

    if (!mounted) {
      return;
    }

    if (result.isAuthenticated) {
      await _controller.setAppLockEnabled(true);
    }

    if (!mounted) {
      return;
    }

    setState(() => _isAuthenticatingAppLock = false);
    _showMessage(
      result.isAuthenticated
          ? 'App Lock enabled for this device.'
          : result.message,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrivacyToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? footer;
  final bool isSaving;

  const _PrivacyToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.value,
    required this.onChanged,
    this.footer,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _PrivacyCardHeader(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                ),
              ),
              const SizedBox(width: 10),
              isSaving
                  ? SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: accentColor,
                      ),
                    )
                  : Switch(
                      value: value,
                      onChanged: onChanged,
                      activeColor: accentColor,
                    ),
            ],
          ),
          if (footer != null) ...<Widget>[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

class _PrivacyActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onPressed;

  const _PrivacyActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: _PrivacyCardHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _AutoLogoutOptions extends StatelessWidget {
  final int selectedMinutes;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _AutoLogoutOptions({
    required this.selectedMinutes,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (minutes) => ChoiceChip(
              label: Text(minutes == 60 ? '1 hour' : '$minutes min'),
              selected: minutes == selectedMinutes,
              onSelected: (_) => onChanged(minutes),
              selectedColor: PassengerUi.blueSoft,
              labelStyle: PassengerUi.bodyText.copyWith(
                color: minutes == selectedMinutes
                    ? PassengerUi.accentBlue
                    : PassengerUi.body,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: minutes == selectedMinutes
                    ? PassengerUi.accentBlue
                    : PassengerUi.border,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PrivacyCardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PrivacyCardHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: PassengerUi.icon, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PassengerUi.valueText,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
