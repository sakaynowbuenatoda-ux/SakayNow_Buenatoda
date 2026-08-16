import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/preferences/app_preferences_controller.dart';
import 'package:sakaynow_buenatoda/pages/driver/driver_home.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferencesController.instance.clearThemePreference();
  });

  tearDown(() async {
    await AppPreferencesController.instance.clearThemePreference();
  });

  testWidgets('offline status uses centered adaptive icon and simple copy', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isActive: false));

    final card = find.byKey(const Key('driver-status-card'));
    final icon = find.byKey(const Key('driver-offline-icon'));

    expect(find.text('You are currently offline'), findsOneWidget);
    expect(
      find.text('Go active to receive new bookings around Buenavista.'),
      findsOneWidget,
    );
    expect(find.text('Current status'), findsNothing);
    expect(tester.widget<Icon>(icon).color, Colors.black);
    expect(tester.getCenter(icon).dx, closeTo(tester.getCenter(card).dx, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline icon becomes white in dark mode', (tester) async {
    await AppPreferencesController.instance.setThemePreference(
      AppThemePreference.dark,
    );

    await tester.pumpWidget(_host(isActive: false, dark: true));

    expect(
      tester.widget<Icon>(find.byKey(const Key('driver-offline-icon'))).color,
      Colors.white,
    );
  });

  testWidgets('active status removes icon and adds a green ring', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isActive: true));

    expect(find.text('Active State'), findsOneWidget);
    expect(
      find.text('You are visible to passengers and ready to accept requests.'),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsNothing);

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const Key('driver-status-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, PassengerUi.successText);
    expect(border.top.width, 2);
  });

  testWidgets('no-internet status shows only centered text', (tester) async {
    await tester.pumpWidget(
      _host(isActive: true, hasInternetConnection: false),
    );

    final card = find.byKey(const Key('driver-status-card'));
    final label = find.text('No internet');
    expect(label, findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.text('Active State'), findsNothing);
    expect(find.text('You are currently offline'), findsNothing);
    expect(
      tester.getCenter(label).dx,
      closeTo(tester.getCenter(card).dx, 0.01),
    );
  });
}

Widget _host({
  required bool isActive,
  bool hasInternetConnection = true,
  bool dark = false,
}) {
  return MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: DriverStatusHeroCard(
            isActive: isActive,
            hasInternetConnection: hasInternetConnection,
          ),
        ),
      ),
    ),
  );
}
