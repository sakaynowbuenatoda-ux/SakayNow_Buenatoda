import 'package:flutter/material.dart';

import '../../models/notification_preferences.dart';
import '../../services/notification_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

typedef NotificationPreferencesLoader =
    Future<NotificationPreferences> Function(String? userId);
typedef NotificationPreferencesSaver =
    Future<void> Function(NotificationPreferences preferences, String? userId);

class NotificationSettingsPage extends StatefulWidget {
  final String? userId;
  final NotificationPreferencesLoader? loadPreferences;
  final NotificationPreferencesSaver? savePreferences;

  const NotificationSettingsPage({
    super.key,
    this.userId,
    this.loadPreferences,
    this.savePreferences,
  });

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final preferences = widget.loadPreferences == null
          ? await NotificationService.instance.loadNotificationPreferences(
              userId: widget.userId,
            )
          : await widget.loadPreferences!(widget.userId);
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = preferences;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = userFacingErrorMessage(
          error,
          fallback:
              'Unable to load notification preferences. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences(NotificationPreferences preferences) async {
    final previousPreferences = _preferences;
    setState(() {
      _preferences = preferences;
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.savePreferences == null) {
        await NotificationService.instance.saveNotificationPreferences(
          preferences,
          userId: widget.userId,
        );
      } else {
        await widget.savePreferences!(preferences, widget.userId);
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = previousPreferences;
        _errorMessage = userFacingErrorMessage(
          error,
          fallback:
              'Unable to save notification preferences. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

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
        title: Text('Notifications', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: _isLoading
            ? const _NotificationLoadingState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PassengerPageHeader(
                    title: 'Notifications',
                    subtitle: '',
                    icon: Icons.notifications_rounded,
                    accentColor: PassengerUi.secondary,
                  ),
                  SizedBox(height: 16),
                  if (_errorMessage != null) ...<Widget>[
                    _NotificationErrorBanner(
                      message: _errorMessage!,
                      onRetry: _loadPreferences,
                    ),
                    SizedBox(height: 14),
                  ],
                  _NotificationToggleCard(
                    title: 'Push Notifications',
                    subtitle: 'Allow SakayNow to send alerts to this device.',
                    icon: Icons.notifications_active_outlined,
                    value: _preferences.pushEnabled,
                    enabled: !_isSaving,
                    onChanged: (value) => _savePreferences(
                      _preferences.copyWith(pushEnabled: value),
                    ),
                  ),
                  SizedBox(height: 14),
                  _NotificationCategoryCard(
                    preferences: _preferences,
                    isSaving: _isSaving,
                    onChanged: _savePreferences,
                  ),
                ],
              ),
      ),
    );
  }
}

class _NotificationCategoryCard extends StatelessWidget {
  final NotificationPreferences preferences;
  final bool isSaving;
  final ValueChanged<NotificationPreferences> onChanged;

  const _NotificationCategoryCard({
    required this.preferences,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categoriesEnabled = preferences.pushEnabled && !isSaving;

    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _NotificationSwitchTile(
            title: 'Ride Updates',
            subtitle: 'Bookings, driver status, cancellations, and trips.',
            icon: Icons.local_taxi_rounded,
            value: preferences.bookingUpdatesEnabled,
            enabled: categoriesEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(bookingUpdatesEnabled: value)),
          ),
          _DividerLine(),
          _NotificationSwitchTile(
            title: 'Messages',
            subtitle: 'Ride chat and support conversation alerts.',
            icon: Icons.chat_bubble_outline_rounded,
            value: preferences.messageUpdatesEnabled,
            enabled: categoriesEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(messageUpdatesEnabled: value)),
          ),
          _DividerLine(),
          _NotificationSwitchTile(
            title: 'Account Alerts',
            subtitle: 'Verification, restrictions, and account access notices.',
            icon: Icons.verified_user_outlined,
            value: preferences.accountUpdatesEnabled,
            enabled: categoriesEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(accountUpdatesEnabled: value)),
          ),
          _DividerLine(),
          _NotificationSwitchTile(
            title: 'System Updates',
            subtitle: 'Reviews, admin notices, and general app updates.',
            icon: Icons.campaign_outlined,
            value: preferences.systemUpdatesEnabled,
            enabled: categoriesEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(systemUpdatesEnabled: value)),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: _NotificationSwitchTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        value: value,
        enabled: enabled,
        onChanged: onChanged,
      ),
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final accentColor = value ? PassengerUi.secondary : PassengerUi.body;

    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 12 : 14,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 40 : 42,
              height: compact ? 40 : 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: PassengerUi.valueText),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PassengerUi.bodyText.copyWith(
                      fontSize: compact ? 12.5 : 13,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: PassengerUi.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: PassengerUi.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState();

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: PassengerUi.secondary,
            ),
          ),
          SizedBox(width: 12),
          Text('Loading notification settings...', style: PassengerUi.bodyText),
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
