import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/preferences/app_preferences_controller.dart';
import 'package:sakaynow_buenatoda/pages/settings/widgets/settings_section_card.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferencesController.instance.setThemePreference(
      AppThemePreference.light,
    );
  });

  tearDown(() async {
    await AppPreferencesController.instance.setThemePreference(
      AppThemePreference.light,
    );
  });

  testWidgets('settings rows match the flat profile action style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSectionCard(
            title: 'Account Settings',
            items: <SettingsTileData>[
              SettingsTileData(
                title: 'Profile Information',
                subtitle: 'Review your personal account details.',
                icon: Icons.person_outline_rounded,
                accentColor: Colors.blue,
                onTap: () {},
              ),
              SettingsTileData(
                title: 'Change Password',
                subtitle: 'Manage login credentials and recovery options.',
                icon: Icons.lock_outline_rounded,
                accentColor: Colors.orange,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Review your personal account details.'), findsNothing);
    expect(
      find.text('Manage login credentials and recovery options.'),
      findsNothing,
    );
    expect(find.byType(Divider), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    final profileIcon = tester.widget<Icon>(
      find.byIcon(Icons.person_outline_rounded),
    );
    final passwordIcon = tester.widget<Icon>(
      find.byIcon(Icons.lock_outline_rounded),
    );
    expect(profileIcon.color, PassengerUi.icon);
    expect(passwordIcon.color, PassengerUi.icon);
  });

  testWidgets('settings row icons turn white in dark mode', (tester) async {
    await AppPreferencesController.instance.setThemePreference(
      AppThemePreference.dark,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSectionCard(
            title: 'Account Settings',
            items: <SettingsTileData>[
              SettingsTileData(
                title: 'Profile Information',
                subtitle: 'Review your personal account details.',
                icon: Icons.person_outline_rounded,
                accentColor: Colors.blue,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final profileIcon = tester.widget<Icon>(
      find.byIcon(Icons.person_outline_rounded),
    );
    expect(profileIcon.color, Colors.white);
  });
}
