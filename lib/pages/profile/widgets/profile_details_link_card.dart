import 'package:flutter/material.dart';

import '../../../utils/user_facing_error_message.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';

class ProfileActionList extends StatefulWidget {
  final VoidCallback onProfileDetailsTap;
  final VoidCallback? onSettingsTap;
  final Future<void> Function()? onLogout;

  const ProfileActionList({
    super.key,
    required this.onProfileDetailsTap,
    this.onSettingsTap,
    this.onLogout,
  });

  @override
  State<ProfileActionList> createState() => _ProfileActionListState();
}

class _ProfileActionListState extends State<ProfileActionList> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _ProfileActionRow(
            key: const Key('profile-details-action'),
            icon: Icons.person_outline_rounded,
            title: 'Profile Details',
            subtitle: 'Personal information and account basics',
            onTap: widget.onProfileDetailsTap,
          ),
          if (widget.onSettingsTap != null) ...<Widget>[
            _divider,
            _ProfileActionRow(
              key: const Key('profile-settings-action'),
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Account, alerts, security, and app preferences',
              onTap: widget.onSettingsTap,
            ),
          ],
          if (widget.onLogout != null) ...<Widget>[
            _divider,
            _ProfileActionRow(
              key: const Key('profile-logout-action'),
              icon: Icons.logout_rounded,
              title: _isLoggingOut ? 'Logging out…' : 'Logout',
              subtitle: 'Sign out of this account',
              foregroundColor: PassengerUi.primary,
              trailing: _isLoggingOut
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        key: const Key('profile-logout-progress'),
                        strokeWidth: 2,
                        color: PassengerUi.primary,
                      ),
                    )
                  : null,
              onTap: _isLoggingOut ? null : _confirmLogout,
            ),
          ],
        ],
      ),
    );
  }

  Widget get _divider =>
      Divider(height: 1, thickness: 1, indent: 64, color: PassengerUi.border);

  Future<void> _confirmLogout() async {
    if (_isLoggingOut || widget.onLogout == null) {
      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout!();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to log out. Please try again.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }
}

class _ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? foregroundColor;
  final Widget? trailing;

  const _ProfileActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.foregroundColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? PassengerUi.title;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: foregroundColor == null
                      ? PassengerUi.blueSoft
                      : PassengerUi.dangerSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: foregroundColor ?? PassengerUi.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: PassengerUi.cardTitle.copyWith(
                        fontSize: 14.5,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.bodyText.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
