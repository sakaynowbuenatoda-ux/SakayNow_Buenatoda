import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/settings/change_update_email_page.dart';
import 'package:sakaynow_buenatoda/pages/settings/email_verification_page.dart';
import 'package:sakaynow_buenatoda/services/email_verification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unverified users see change email and verification actions', (
    tester,
  ) async {
    final service = _FakeEmailVerificationService(
      status: const EmailVerificationStatus(
        email: 'passenger@example.com',
        isVerified: false,
        hasSignedInUser: true,
      ),
    );

    await _pumpEmailVerificationPage(tester, service);

    expect(find.text('Email Not Verified'), findsOneWidget);
    expect(find.text('Change Email'), findsOneWidget);
    expect(find.text('Send Verification Email'), findsOneWidget);
    expect(find.text('Refresh Status'), findsOneWidget);
    expect(_newEmailField(), findsNothing);

    await tester.tap(find.text('Change Email'));
    await tester.pumpAndSettle();

    expect(_newEmailField(), findsOneWidget);
    expect(_currentPasswordField(), findsOneWidget);
  });

  testWidgets('verified users route to update email page', (tester) async {
    final service = _FakeEmailVerificationService(
      status: const EmailVerificationStatus(
        email: 'passenger@example.com',
        isVerified: true,
        hasSignedInUser: true,
      ),
    );

    await _pumpEmailVerificationPage(tester, service);

    expect(find.text('Verified Email'), findsOneWidget);
    expect(find.text('Verification Complete'), findsOneWidget);
    expect(find.text('Update Email'), findsOneWidget);
    expect(find.text('Send Verification Email'), findsNothing);
    expect(_newEmailField(), findsNothing);

    await tester.tap(find.text('Update Email'));
    await tester.pumpAndSettle();

    expect(_newEmailField(), findsOneWidget);
    expect(_currentPasswordField(), findsOneWidget);
  });

  testWidgets('invalid and same email values do not submit update request', (
    tester,
  ) async {
    final service = _FakeEmailVerificationService(
      status: const EmailVerificationStatus(
        email: 'passenger@example.com',
        isVerified: false,
        hasSignedInUser: true,
      ),
    );

    await _pumpChangeUpdateEmailPage(tester, service);

    await tester.enterText(_newEmailField(), 'not-an-email');
    await tester.enterText(_currentPasswordField(), 'password123');
    await _tapSendChangeLink(tester);

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(service.requestEmailUpdateCalls, 0);

    await tester.enterText(_newEmailField(), 'passenger@example.com');
    await _tapSendChangeLink(tester);

    expect(find.text('Enter a different email address'), findsOneWidget);
    expect(service.requestEmailUpdateCalls, 0);
  });

  testWidgets(
    'email update waits for verified refresh before displayed email changes',
    (tester) async {
      final service = _FakeEmailVerificationService(
        status: const EmailVerificationStatus(
          email: 'passenger@example.com',
          isVerified: false,
          hasSignedInUser: true,
        ),
      );

      await _pumpChangeUpdateEmailPage(tester, service);

      await tester.enterText(_newEmailField(), 'new.passenger@example.com');
      await tester.enterText(_currentPasswordField(), 'password123');
      await _tapSendChangeLink(tester);

      expect(service.requestEmailUpdateCalls, 1);
      expect(service.requestedNewEmail, 'new.passenger@example.com');
      expect(service.requestedPassword, 'password123');
      expect(find.text('Current email: passenger@example.com'), findsOneWidget);
      expect(
        find.textContaining(
          'Check new.passenger@example.com, open the verification link',
        ),
        findsOneWidget,
      );

      service.status = const EmailVerificationStatus(
        email: 'new.passenger@example.com',
        isVerified: true,
        hasSignedInUser: true,
      );

      await tester.ensureVisible(find.text('Refresh Status'));
      await tester.tap(find.text('Refresh Status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(service.syncVerifiedEmailToProfileCalls, 1);
      expect(
        find.text('Current email: new.passenger@example.com'),
        findsOneWidget,
      );
      expect(find.text('Current email: passenger@example.com'), findsNothing);
      expect(
        find.textContaining(
          'Check new.passenger@example.com, open the verification link',
        ),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpEmailVerificationPage(
  WidgetTester tester,
  _FakeEmailVerificationService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: EmailVerificationPage(verificationService: service)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpChangeUpdateEmailPage(
  WidgetTester tester,
  _FakeEmailVerificationService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeUpdateEmailPage(
        verificationService: service,
        initialStatus: service.status,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _newEmailField() {
  return find.widgetWithText(TextFormField, 'New email');
}

Finder _currentPasswordField() {
  return find.widgetWithText(TextFormField, 'Current password');
}

Future<void> _tapSendChangeLink(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Send Change Link'));
  await tester.tap(find.text('Send Change Link'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _FakeEmailVerificationService implements EmailVerificationClient {
  EmailVerificationStatus status;
  int sendVerificationEmailCalls = 0;
  int requestEmailUpdateCalls = 0;
  int syncVerifiedEmailToProfileCalls = 0;
  String? requestedNewEmail;
  String? requestedPassword;

  _FakeEmailVerificationService({required this.status});

  @override
  Future<EmailVerificationStatus> loadStatus({bool refresh = false}) async {
    return status;
  }

  @override
  Future<void> requestEmailUpdate({
    required String newEmail,
    required String currentPassword,
  }) async {
    requestEmailUpdateCalls += 1;
    requestedNewEmail = newEmail;
    requestedPassword = currentPassword;
  }

  @override
  Future<void> sendVerificationEmail() async {
    sendVerificationEmailCalls += 1;
  }

  @override
  Future<void> syncVerifiedEmailToProfile() async {
    syncVerifiedEmailToProfileCalls += 1;
  }
}
