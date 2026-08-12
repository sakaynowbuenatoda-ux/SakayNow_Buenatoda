import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/preferences/privacy_security_preferences_controller.dart';
import 'package:sakaynow_buenatoda/core/session/privacy_security_session_guard.dart';
import 'package:sakaynow_buenatoda/services/device_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final preferences = PrivacySecurityPreferencesController.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'privacy_security_app_lock_enabled': true,
    });
    await preferences.load();
  });

  testWidgets(
    'authenticates before mounting the signed-in app on a fresh start',
    (tester) async {
      final deviceAuth = _FakeDeviceAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: PrivacySecuritySessionGuard(
            deviceAuthService: deviceAuth,
            isSignedIn: () => true,
            signedInChanges: const Stream<bool>.empty(),
            child: const Text('Signed-in app'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Signed-in app'), findsNothing);
      expect(find.text('App Locked'), findsOneWidget);
      expect(deviceAuth.authenticationCount, 1);

      deviceAuth.completeAuthentication(isAuthenticated: true);
      await tester.pump();

      expect(find.text('Signed-in app'), findsOneWidget);
      expect(find.text('App Locked'), findsNothing);
    },
  );

  testWidgets('does not authenticate again when the app resumes', (
    tester,
  ) async {
    final deviceAuth = _FakeDeviceAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySecuritySessionGuard(
          deviceAuthService: deviceAuth,
          isSignedIn: () => true,
          signedInChanges: const Stream<bool>.empty(),
          child: const Text('Signed-in app'),
        ),
      ),
    );
    await tester.pump();
    deviceAuth.completeAuthentication(isAuthenticated: true);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(deviceAuth.authenticationCount, 1);
    expect(find.text('Signed-in app'), findsOneWidget);
  });

  testWidgets('does not lock a user who signs in after startup', (
    tester,
  ) async {
    final deviceAuth = _FakeDeviceAuthService();
    final signedInChanges = StreamController<bool>();
    var isSignedIn = false;
    addTearDown(signedInChanges.close);

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySecuritySessionGuard(
          deviceAuthService: deviceAuth,
          isSignedIn: () => isSignedIn,
          signedInChanges: signedInChanges.stream,
          child: const Text('Authentication screen'),
        ),
      ),
    );

    signedInChanges.add(false);
    await tester.pump();
    expect(find.text('Authentication screen'), findsOneWidget);

    isSignedIn = true;
    signedInChanges.add(true);
    await tester.pump();

    expect(deviceAuth.authenticationCount, 0);
    expect(find.text('Authentication screen'), findsOneWidget);
  });
}

class _FakeDeviceAuthService extends DeviceAuthService {
  final Completer<DeviceAuthResult> _authentication =
      Completer<DeviceAuthResult>();
  int authenticationCount = 0;

  @override
  Future<DeviceAuthResult> authenticate({String reason = ''}) {
    authenticationCount += 1;
    return _authentication.future;
  }

  void completeAuthentication({required bool isAuthenticated}) {
    _authentication.complete(
      DeviceAuthResult(
        isAuthenticated: isAuthenticated,
        message: isAuthenticated ? 'Device lock confirmed.' : 'Cancelled.',
      ),
    );
  }
}
