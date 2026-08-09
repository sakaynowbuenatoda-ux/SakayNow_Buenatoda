import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('page header uses compact typography and a trailing tonal icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PassengerPageHeader(
              title: 'Dashboard',
              subtitle: 'A quick view of trips, payments, and safety status.',
              icon: Icons.insights_rounded,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.insights_rounded), findsOneWidget);

    final titleRect = tester.getRect(find.text('Dashboard'));
    final iconRect = tester.getRect(find.byIcon(Icons.insights_rounded));
    expect(iconRect.center.dx, greaterThan(titleRect.center.dx));

    final title = tester.widget<Text>(find.text('Dashboard'));
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(title.style?.fontSize, 20);
  });

  testWidgets('page header stays neat without subtitle text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PassengerPageHeader(
            title: 'Payment Methods',
            subtitle: '',
            icon: Icons.credit_card_rounded,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Payment Methods'), findsOneWidget);
    expect(find.byIcon(Icons.credit_card_rounded), findsOneWidget);
  });

  testWidgets('page header can omit its decorative icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PassengerPageHeader(
            title: 'Settings',
            subtitle: 'Manage the admin console preferences.',
            icon: Icons.settings_suggest_rounded,
            showIcon: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.settings_suggest_rounded), findsNothing);
  });
}
