import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/notification_preferences.dart';
import 'package:sakaynow_buenatoda/pages/settings/notification_settings_page.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets(
    'notification categories render and a toggle persists on reload',
    (tester) async {
      var stored = const NotificationPreferences();

      Widget buildPage() {
        return MaterialApp(
          home: NotificationSettingsPage(
            userId: 'test-user',
            loadPreferences: (_) async => stored,
            savePreferences: (preferences, _) async {
              stored = preferences;
            },
          ),
        );
      }

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Ride Updates'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Account Alerts'), findsOneWidget);
      expect(find.text('System Updates'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(
        find.text('Bookings, driver status, cancellations, and trips.'),
        findsOneWidget,
      );
      expect(find.byType(Divider), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.local_taxi_rounded)).color,
        PassengerUi.dark,
      );

      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();
      expect(stored.bookingUpdatesEnabled, isFalse);
      expect(stored.messageUpdatesEnabled, isTrue);
      expect(stored.accountUpdatesEnabled, isTrue);
      expect(stored.systemUpdatesEnabled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final rideUpdatesSwitch = tester.widget<Switch>(
        find.byType(Switch).at(1),
      );
      expect(rideUpdatesSwitch.value, isFalse);
    },
  );
}
