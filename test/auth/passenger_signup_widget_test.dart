import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_signup.dart';

void main() {
  testWidgets('PassengerSignup renders Quick Registration single-step form and supports Senior Citizen option', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PassengerSignup()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Passenger Quick Registration'), findsOneWidget);
    expect(find.text('Create Passenger Account'), findsOneWidget);

    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Passenger Type'), findsOneWidget);

    // Verify step indicators and file upload buttons are removed for quick registration
    expect(find.text('ID Verification'), findsNothing);
    expect(find.text('Selfie Verification'), findsNothing);

    await tester.tap(find.text('Regular'));
    await tester.pumpAndSettle();

    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Senior Citizen'), findsOneWidget);

    await tester.tap(find.text('Senior Citizen').last);
    await tester.pumpAndSettle();

    expect(find.text('Senior Citizen'), findsOneWidget);
  });
}
