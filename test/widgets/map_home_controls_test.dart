import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/maps/map_type_toggle.dart';

void main() {
  testWidgets('current location control sits below the map type toggle', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const MapTypeToggle(),
                const SizedBox(height: 8),
                MapCurrentLocationButton(
                  key: const Key('current-location-control'),
                  onPressed: () => tapCount += 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final mapTypeToggle = find.byType(MapTypeToggle);
    final currentLocationControl = find.byKey(
      const Key('current-location-control'),
    );

    expect(find.byTooltip('Current location'), findsOneWidget);
    expect(
      tester.getTopLeft(currentLocationControl).dy,
      tester.getBottomLeft(mapTypeToggle).dy + 8,
    );

    await tester.tap(currentLocationControl);
    expect(tapCount, 1);
  });
}
