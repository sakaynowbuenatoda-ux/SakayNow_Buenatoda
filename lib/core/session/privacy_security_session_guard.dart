import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../preferences/privacy_security_preferences_controller.dart';
import '../../services/device_auth_service.dart';
import 'session_service.dart';

class PrivacySecuritySessionGuard extends StatefulWidget {
  final Widget child;

  const PrivacySecuritySessionGuard({super.key, required this.child});

  @override
  State<PrivacySecuritySessionGuard> createState() =>
      _PrivacySecuritySessionGuardState();
}

class _PrivacySecuritySessionGuardState
    extends State<PrivacySecuritySessionGuard>
    with WidgetsBindingObserver {
  final PrivacySecurityPreferencesController _preferences =
      PrivacySecurityPreferencesController.instance;
  final DeviceAuthService _deviceAuthService = DeviceAuthService();

  Timer? _autoLogoutTimer;
  StreamSubscription<User?>? _authSubscription;
  DateTime? _backgroundedAt;
  bool _isSigningOut = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  String? _lockMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preferences.addListener(_handlePreferencesChanged);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      _scheduleAutoLogoutTimer();
    });
    _scheduleAutoLogoutTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preferences.removeListener(_handlePreferencesChanged);
    _autoLogoutTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_isAuthenticating) {
          return;
        }

        _backgroundedAt ??= DateTime.now();
        _autoLogoutTimer?.cancel();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(),
      child: Stack(
        children: <Widget>[
          widget.child,
          if (_isLocked)
            Positioned.fill(
              child: _DeviceLockOverlay(
                message: _lockMessage,
                isAuthenticating: _isAuthenticating,
                onUnlock: _authenticateForUnlock,
                onLogout: _signOut,
              ),
            ),
        ],
      ),
    );
  }

  void _handlePreferencesChanged() {
    _scheduleAutoLogoutTimer();
  }

  void _handleAppResumed() {
    if (_isAuthenticating) {
      return;
    }

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;

    if (!_hasSignedInUser) {
      _autoLogoutTimer?.cancel();
      return;
    }

    if (_preferences.autoLogoutEnabled && backgroundedAt != null) {
      final inactiveDuration = DateTime.now().difference(backgroundedAt);
      if (inactiveDuration >= _preferences.autoLogoutDuration) {
        _signOut();
        return;
      }
    }

    if (_preferences.appLockEnabled && backgroundedAt != null) {
      _lockAndAuthenticate();
      return;
    }

    _recordActivity();
  }

  void _recordActivity() {
    if (!_hasSignedInUser || _isSigningOut || _isLocked) {
      _autoLogoutTimer?.cancel();
      return;
    }

    _scheduleAutoLogoutTimer();
  }

  void _scheduleAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();

    if (!_preferences.autoLogoutEnabled || !_hasSignedInUser || _isSigningOut) {
      return;
    }

    _autoLogoutTimer = Timer(_preferences.autoLogoutDuration, _signOut);
  }

  bool get _hasSignedInUser => FirebaseAuth.instance.currentUser != null;

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    if (!_hasSignedInUser) {
      setState(() {
        _isLocked = false;
        _isAuthenticating = false;
        _lockMessage = null;
      });
      return;
    }

    _isSigningOut = true;
    _autoLogoutTimer?.cancel();

    try {
      await SessionService.signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
          _isLocked = false;
          _isAuthenticating = false;
          _lockMessage = null;
        });
      }
    }
  }

  void _lockAndAuthenticate() {
    if (_isSigningOut || !_hasSignedInUser) {
      return;
    }

    _autoLogoutTimer?.cancel();
    setState(() {
      _isLocked = true;
      _lockMessage = null;
    });

    unawaited(_authenticateForUnlock());
  }

  Future<void> _authenticateForUnlock() async {
    if (_isAuthenticating || !_hasSignedInUser) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _lockMessage = null;
    });

    final result = await _deviceAuthService.authenticate(
      reason: 'Unlock SakayNow with your device lock.',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = false;
      _isLocked = !result.isAuthenticated;
      _lockMessage = result.isAuthenticated ? null : result.message;
    });

    if (result.isAuthenticated) {
      _recordActivity();
    }
  }
}

class _DeviceLockOverlay extends StatelessWidget {
  final String? message;
  final bool isAuthenticating;
  final VoidCallback onUnlock;
  final VoidCallback onLogout;

  const _DeviceLockOverlay({
    required this.message,
    required this.isAuthenticating,
    required this.onUnlock,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.phonelink_lock_outlined,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'App Locked',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message ??
                      'Use your device PIN, password, pattern, or biometrics to unlock SakayNow.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isAuthenticating ? null : onUnlock,
                    icon: isAuthenticating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(isAuthenticating ? 'Unlocking...' : 'Unlock'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isAuthenticating ? null : onLogout,
                  child: const Text('Log out instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
