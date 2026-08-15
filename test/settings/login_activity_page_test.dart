import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/login_activity_entry.dart';
import 'package:sakaynow_buenatoda/pages/settings/login_activity_page.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('shows previous successful logins in newest-first order', (
    tester,
  ) async {
    final entries = <LoginActivityEntry>[
      LoginActivityEntry(
        id: 'latest',
        userId: 'user-1',
        signedInAt: DateTime(2026, 8, 12, 14, 35),
        platform: 'android',
        authMethod: 'password',
      ),
      LoginActivityEntry(
        id: 'previous',
        userId: 'user-1',
        signedInAt: DateTime(2026, 8, 10, 8, 5),
        platform: 'windows',
        authMethod: 'password',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: LoginActivityPage(
          userId: 'user-1',
          signedInEmail: 'ana@example.com',
          loginHistory: Stream<List<LoginActivityEntry>>.value(entries),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent Logins'), findsOneWidget);
    expect(find.text('a***@example.com'), findsOneWidget);
    expect(find.text('Android device'), findsOneWidget);
    expect(find.text('Windows device'), findsOneWidget);
    expect(find.text('Most recent'), findsOneWidget);
    expect(find.text('Email and password'), findsNWidgets(2));
    expect(find.text('August 12, 2026 at 2:35 PM'), findsOneWidget);
    expect(find.text('August 10, 2026 at 8:05 AM'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.alternate_email_rounded)).color,
      PassengerUi.dark,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.android_rounded)).color,
      PassengerUi.dark,
    );
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('explains when no recorded login history exists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginActivityPage(
          userId: 'user-1',
          signedInEmail: 'ana@example.com',
          loginHistory: Stream<List<LoginActivityEntry>>.value(
            const <LoginActivityEntry>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved login history yet'), findsOneWidget);
    expect(
      find.text('Successful logins made after this update will appear here.'),
      findsOneWidget,
    );
  });
}
