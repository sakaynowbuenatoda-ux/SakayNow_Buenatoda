import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('home opens half-height and smoothly expands to two thirds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassengerHomeSplitLayout(
            map: const ColoredBox(color: Colors.blue),
            header: const Align(
              alignment: Alignment.topLeft,
              child: Text('Home header'),
            ),
            child: Column(
              children: List<Widget>.generate(
                20,
                (index) =>
                    SizedBox(height: 72, child: Text('Home item $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('home-content-sheet-surface'));
    expect(tester.getTopLeft(sheet).dy, closeTo(400, 1));
    expect(find.byKey(const Key('home-map-pane')), findsOneWidget);

    await tester.dragFrom(
      tester.getTopLeft(sheet) + const Offset(200, 36),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(sheet).dy, closeTo(800 / 3, 2));
    expect(tester.takeException(), isNull);
  });
}
