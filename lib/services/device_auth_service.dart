import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class DeviceAuthService {
  DeviceAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> isDeviceLockAvailable() async {
    try {
      return _localAuthentication.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<DeviceAuthResult> authenticate({
    String reason =
        'Authenticate with biometrics or your device PIN to open SakayNow.',
  }) async {
    try {
      final isSupported = await isDeviceLockAvailable();
      if (!isSupported) {
        return const DeviceAuthResult(
          isAuthenticated: false,
          message:
              'Set up a device PIN, password, pattern, or biometrics first.',
        );
      }

      final isAuthenticated = await _localAuthentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return DeviceAuthResult(
        isAuthenticated: isAuthenticated,
        message: isAuthenticated
            ? 'Device lock confirmed.'
            : 'Device authentication was cancelled.',
      );
    } on PlatformException catch (error) {
      return DeviceAuthResult(
        isAuthenticated: false,
        message: _messageFor(error),
      );
    } catch (_) {
      return const DeviceAuthResult(
        isAuthenticated: false,
        message: 'Device authentication is unavailable on this device.',
      );
    }
  }

  String _messageFor(PlatformException error) {
    return switch (error.code) {
      'NotAvailable' ||
      'not_available' => 'Device authentication is unavailable on this device.',
      'NotEnrolled' || 'not_enrolled' =>
        'Set up a device PIN, password, pattern, or biometrics first.',
      'PasscodeNotSet' ||
      'passcode_not_set' => 'Set up a device PIN, password, or passcode first.',
      'LockedOut' || 'locked_out' =>
        'Device authentication is temporarily locked. Try again later.',
      'PermanentlyLockedOut' || 'permanently_locked_out' =>
        'Device authentication is locked. Unlock it in your device settings.',
      _ => error.message ?? 'Device authentication failed.',
    };
  }
}

class DeviceAuthResult {
  final bool isAuthenticated;
  final String message;

  const DeviceAuthResult({
    required this.isAuthenticated,
    required this.message,
  });
}
