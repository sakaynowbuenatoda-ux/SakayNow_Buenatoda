import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/settings/app_preferences_page.dart';
import 'package:sakaynow_buenatoda/pages/settings/developers.dart';
import 'package:sakaynow_buenatoda/pages/settings/privacy_security_page.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('app preferences uses flat icons with option subtext', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppPreferencesPage()));

    expect(find.text('App Preferences'), findsOneWidget);
    expect(
      find.text(
        'Adjust appearance and reading size preferences for the app experience.',
      ),
      findsNothing,
    );
    expect(find.text('Choose how the interface should look.'), findsOneWidget);
    expect(
      find.text('A darker interface for lower-light viewing.'),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<Icon>(find.byIcon(Icons.light_mode_rounded))
          .first
          .color,
      PassengerUi.dark,
    );
  });

  testWidgets('privacy settings uses flat rows with subtext and no arrows', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacySecurityPage()));

    expect(find.text('Privacy and Security'), findsOneWidget);
    expect(
      find.text('Review the history of successful account logins.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.manage_history_rounded)).color,
      PassengerUi.dark,
    );
  });

  testWidgets('developers page uses a bare dark header icon with subtext', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevelopersPage()));

    expect(
      tester.widget<Icon>(find.byIcon(Icons.groups_rounded)).color,
      PassengerUi.dark,
    );
    expect(
      find.text('Meet the developers of SakayNow Buenatoda'),
      findsOneWidget,
    );
    expect(find.text('Lead Researcher'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });
}
