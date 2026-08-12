import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../preferences/privacy_security_preferences_controller.dart';
import '../../services/device_auth_service.dart';
import 'session_service.dart';

class PrivacySecuritySessionGuard extends StatefulWidget {
  final Widget child;
  final DeviceAuthService? deviceAuthService;
  final bool Function()? isSignedIn;
  final Stream<bool>? signedInChanges;

  const PrivacySecuritySessionGuard({
    super.key,
    required this.child,
    this.deviceAuthService,
    this.isSignedIn,
    this.signedInChanges,
  });

  @override
  State<PrivacySecuritySessionGuard> createState() =>
      _PrivacySecuritySessionGuardState();
}

class _PrivacySecuritySessionGuardState
    extends State<PrivacySecuritySessionGuard>
    with WidgetsBindingObserver {
  final PrivacySecurityPreferencesController _preferences =
      PrivacySecurityPreferencesController.instance;
  late final DeviceAuthService _deviceAuthService;

  Timer? _autoLogoutTimer;
  StreamSubscription<bool>? _authSubscription;
  DateTime? _backgroundedAt;
  bool _isSigningOut = false;
  bool _isLocked = false;
  bool _isResolvingStartupSession = false;
  bool _isAuthenticating = false;
  bool _startupAuthenticationScheduled = false;
  String? _lockMessage;

  @override
  void initState() {
    super.initState();
    _deviceAuthService = widget.deviceAuthService ?? DeviceAuthService();
    WidgetsBinding.instance.addObserver(this);
    _preferences.addListener(_handlePreferencesChanged);

    final hasCurrentUser = _hasSignedInUser;
    _isLocked = _preferences.appLockEnabled && hasCurrentUser;
    _isResolvingStartupSession = _preferences.appLockEnabled && !hasCurrentUser;

    final signedInChanges =
        widget.signedInChanges ??
        FirebaseAuth.instance.authStateChanges().map((user) => user != null);
    _authSubscription = signedInChanges.listen(_handleAuthStateChanged);
    _scheduleAutoLogoutTimer();

    if (_isLocked) {
      _scheduleStartupAuthentication();
    }
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
      child: _buildGuardedContent(),
    );
  }

  Widget _buildGuardedContent() {
    if (_isResolvingStartupSession) {
      return const _StartupSessionPlaceholder();
    }

    if (_isLocked) {
      return _DeviceLockOverlay(
        message: _lockMessage,
        isAuthenticating: _isAuthenticating,
        onUnlock: _authenticateForUnlock,
        onLogout: _signOut,
      );
    }

    return widget.child;
  }

  void _handlePreferencesChanged() {
    _scheduleAutoLogoutTimer();
  }

  void _handleAuthStateChanged(bool isSignedIn) {
    if (!mounted) {
      return;
    }

    if (_isResolvingStartupSession) {
      final shouldLock = _preferences.appLockEnabled && isSignedIn;

      setState(() {
        _isResolvingStartupSession = false;
        _isLocked = shouldLock;
        _lockMessage = null;
      });

      if (shouldLock) {
        _scheduleStartupAuthentication();
      } else {
        _scheduleAutoLogoutTimer();
      }
      return;
    }

    if (!isSignedIn && (_isLocked || _isAuthenticating)) {
      setState(() {
        _isLocked = false;
        _isAuthenticating = false;
        _lockMessage = null;
      });
    }

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

    if (!_preferences.autoLogoutEnabled ||
        !_hasSignedInUser ||
        _isSigningOut ||
        _isLocked ||
        _isResolvingStartupSession) {
      return;
    }

    _autoLogoutTimer = Timer(_preferences.autoLogoutDuration, _signOut);
  }

  bool get _hasSignedInUser =>
      widget.isSignedIn?.call() ?? FirebaseAuth.instance.currentUser != null;

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
          _isResolvingStartupSession = false;
          _isAuthenticating = false;
          _lockMessage = null;
        });
      }
    }
  }

  void _scheduleStartupAuthentication() {
    if (_startupAuthenticationScheduled || !_isLocked) {
      return;
    }

    _startupAuthenticationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupAuthenticationScheduled = false;
      if (!mounted || !_isLocked) {
        return;
      }

      unawaited(_authenticateForUnlock());
    });
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
      reason:
          'Authenticate with biometrics or your device PIN to open SakayNow.',
    );

    if (!mounted) {
      return;
    }

    if (!_hasSignedInUser) {
      setState(() {
        _isAuthenticating = false;
        _isLocked = false;
        _lockMessage = null;
      });
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
                      'Authenticate with biometrics or your device PIN before continuing to SakayNow.',
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

class _StartupSessionPlaceholder extends StatelessWidget {
  const _StartupSessionPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Securing your session...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
