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
            onBookTap: () => bookingPressed = true,
            onTap: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.text('Queue'), findsNothing);
    expect(find.text('Book Now'), findsOneWidget);
    expect(find.text('Book'), findsNothing);
    expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(find.byIcon(Icons.book_online_rounded), findsNothing);
    expect(find.byIcon(Icons.local_taxi_rounded), findsNothing);
    expect(find.text('4'), findsOneWidget);
    _expectNavigationIsFloating(tester);
    _expectNotchIsCentered(tester);
    expect(
      tester.widget<BottomAppBar>(find.byType(BottomAppBar)).shape,
      isNotNull,
    );
    final bookingMaterial = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(PassengerBookingButton),
            matching: find.byType(Material),
          ),
        )
        .singleWhere((material) => material.shape is CircleBorder);
    expect(bookingMaterial.color, PassengerUi.dark);

    await tester.tap(find.text('Book Now'));
    expect(bookingPressed, isTrue);

    await tester.tap(find.text('Dashboard'));
    expect(selectedIndex, 2);

    await tester.tap(find.text('Profile'));
    expect(selectedIndex, 3);
  });

  testWidgets('driver navigation uses availability notch between four tabs', (
    tester,
  ) async {
    int? selectedIndex;
    var availabilityPressed = false;
    var isActive = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            floatingActionButton: DriverAvailabilityButton(
              isActive: isActive,
              onPressed: () => setState(() => isActive = !isActive),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomNavWidget(
              currentIndex: 0,
              isDriver: true,
              isDriverActive: isActive,
              messageUnreadCount: 7,
              onDriverAvailabilityTap: () {
                availabilityPressed = true;
                setState(() => isActive = !isActive);
              },
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Queue'), findsNothing);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Go Active'), findsOneWidget);
    expect(find.text('Go Offline'), findsNothing);
    expect(find.text('History'), findsNothing);
    expect(find.text('Book Now'), findsNothing);
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
    _expectNavigationIsFloating(tester);
    _expectNotchIsCentered(tester);
    expect(
      tester.widget<BottomAppBar>(find.byType(BottomAppBar)).shape,
      isNotNull,
    );

    await tester.tap(find.text('Go Active'));
    await tester.pump();
    expect(availabilityPressed, isTrue);
    expect(find.text('Go Offline'), findsOneWidget);
    expect(find.text('Go Active'), findsNothing);

    await tester.tap(find.text('Dashboard'));
    expect(selectedIndex, 2);

    await tester.tap(find.text('Profile'));
    expect(selectedIndex, 3);
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

void _expectNavigationIsFloating(WidgetTester tester) {
  final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final navigationBounds = tester.getRect(find.byType(BottomAppBar));

  expect(navigationBounds.left, greaterThan(0));
  expect(navigationBounds.right, lessThan(screenSize.width));
  expect(navigationBounds.bottom, lessThan(screenSize.height));
}

void _expectNotchIsCentered(WidgetTester tester) {
  final bottomAppBar = tester.widget<BottomAppBar>(find.byType(BottomAppBar));
  final navigationBounds = tester.getRect(find.byType(BottomAppBar));
  final host = Offset.zero & navigationBounds.size;
  final deliberatelyOffsetGuest = Rect.fromCircle(
    center: Offset(host.center.dx + 70, 0),
    radius: 42,
  );
  final barPath = bottomAppBar.shape!.getOuterPath(
    host,
    deliberatelyOffsetGuest,
  );

  expect(barPath.contains(Offset(host.center.dx, 1)), isFalse);
  expect(barPath.contains(Offset(host.center.dx + 70, 1)), isTrue);
}
