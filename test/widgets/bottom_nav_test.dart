import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/bottom_nav.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('passenger navigation keeps four tabs around booking action', (
    tester,
  ) async {
    int? selectedIndex;
    var bookingPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: PassengerBookingButton(
            onPressed: () => bookingPressed = true,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomNavWidget(
            currentIndex: 0,
            messageUnreadCount: 4,
            onTap: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Queue'), findsNothing);
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    final bookingMaterial = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(PassengerBookingButton),
            matching: find.byType(Material),
          ),
        )
        .singleWhere((material) => material.shape is CircleBorder);
    expect(bookingMaterial.color, PassengerUi.dark);

    await tester.tap(find.text('Book'));
    expect(bookingPressed, isTrue);

    await tester.tap(find.text('History'));
    expect(selectedIndex, 2);
  });

  testWidgets('driver navigation preserves all five destinations and badges', (
    tester,
  ) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavWidget(
            currentIndex: 0,
            isDriver: true,
            messageUnreadCount: 7,
            queueRequestCount: 3,
            onTap: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Book'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    expect(selectedIndex, 4);
  });

  testWidgets('navigation fits on a compact phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: PassengerBookingButton(onPressed: () {}),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomNavWidget(currentIndex: 3, onTap: (_) {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
