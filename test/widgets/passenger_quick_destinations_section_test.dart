import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/passenger/passenger_data.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_quick_destinations_section.dart';

void main() {
  testWidgets('one-tap destinations use a compact horizontal card layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openedAll = false;
    PassengerQuickDestination? selectedDestination;
    const destinations = <PassengerQuickDestination>[
      PassengerQuickDestination(
        id: 'home',
        label: 'Home',
        pinName: 'Poblacion',
        icon: Icons.home_rounded,
        accentColor: Color(0xFF030213),
        backgroundColor: Color(0xFFF3F4F6),
      ),
      PassengerQuickDestination(
        id: 'school',
        label: 'School',
        pinName: 'Community College',
        icon: Icons.school_rounded,
        accentColor: Color(0xFF047857),
        backgroundColor: Color(0xFFE7F8EF),
      ),
      PassengerQuickDestination(
        id: 'work',
        label: 'Work',
        pinName: 'Municipal Hall',
        icon: Icons.work_rounded,
        accentColor: Color(0xFF2563EB),
        backgroundColor: Color(0xFFEFF6FF),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PassengerQuickDestinationsSection(
              destinations: destinations,
              onSeeAllTap: () => openedAll = true,
              onDestinationTap: (destination) {
                selectedDestination = destination;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('One-tap booking'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
    expect(find.byType(PassengerQuickDestinationCard), findsNWidgets(3));

    final homeCard = find.byKey(
      const ValueKey<String>('quick-destination-card-home'),
    );
    expect(tester.getSize(homeCard), const Size(112, 134));

    await tester.tap(homeCard);
    expect(selectedDestination?.id, 'home');

    await tester.tap(find.text('View all'));
    expect(openedAll, isTrue);
  });
}
