import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/settings/widgets/settings_section_card.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
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
    expect(profileIcon.color, PassengerUi.dark);
    expect(passwordIcon.color, PassengerUi.dark);
  });
}
