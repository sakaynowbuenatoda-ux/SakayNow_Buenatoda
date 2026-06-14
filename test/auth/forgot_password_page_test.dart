import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sakaynow_buenatoda/pages/auth/forgot_password_page.dart';
import 'package:sakaynow_buenatoda/services/password_reset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('prefills valid initial email', (tester) async {
    await _pumpForgotPasswordPage(
      tester,
      initialEmail: 'passenger@example.com',
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, 'passenger@example.com');
  });

  testWidgets('opens blank when no initial email is provided', (tester) async {
    await _pumpForgotPasswordPage(tester);

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, isEmpty);
    expect(find.text('Email'), findsWidgets);
  });

  testWidgets('shows spam folder guidance', (tester) async {
    await _pumpForgotPasswordPage(tester);

    expect(
      find.text('If no email arrives, please check your spam or junk folder.'),
      findsOneWidget,
    );
  });

  testWidgets('disables send button during cooldown', (tester) async {
    var now = DateTime(2026, 6, 12, 9);
    final limiter = PasswordResetLimiter(now: () => now);
    await limiter.recordAttempt();

    await _pumpForgotPasswordPage(
      tester,
      initialEmail: 'passenger@example.com',
      limiter: limiter,
    );

    expect(find.text('Try Again in 1:00'), findsOneWidget);

    final buttonFinder = find.ancestor(
      of: find.text('Try Again in 1:00'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    final button = tester.widget<ButtonStyleButton>(buttonFinder);
    expect(button.onPressed, isNull);

    now = now.add(const Duration(minutes: 1, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows generic success notice after sending', (tester) async {
    final sender = _FakePasswordResetSender();

    await _pumpForgotPasswordPage(
      tester,
      initialEmail: 'passenger@example.com',
      resetService: sender,
    );

    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(sender.sentEmail, 'passenger@example.com');
    expect(
      find.text(
        'If an account exists, a reset link was sent. Please check your inbox and spam folder.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpForgotPasswordPage(
  WidgetTester tester, {
  String? initialEmail,
  PasswordResetSender? resetService,
  PasswordResetLimiter? limiter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ForgotPasswordPage(
        initialEmail: initialEmail,
        resetService: resetService ?? _FakePasswordResetSender(),
        limiter: limiter ?? PasswordResetLimiter(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

class _FakePasswordResetSender implements PasswordResetSender {
  String? sentEmail;

  @override
  Future<void> sendResetLink(String email) async {
    sentEmail = email;
  }
}
