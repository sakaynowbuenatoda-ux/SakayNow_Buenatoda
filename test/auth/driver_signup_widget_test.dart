import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/driver_signup.dart';

void main() {
  testWidgets(
    'DriverSignUp navigates 3-step workflow and enforces vehicle field validation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DriverSignUp())),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 3 step indicator labels are rendered
      expect(find.text('Basic Info'), findsOneWidget);
      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('Driver IDs'), findsOneWidget);

      // Verify currently on step 1: Basic Info fields are present
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Vehicle Information & Photos'), findsNothing);

      // Fill in valid Basic Info to proceed to Step 2
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'driver@buenatoda.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First Name'),
        'Jose',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last Name'),
        'Rizal',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '30');
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Gender'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Male').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'driverPass123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'driverPass123',
      );
      await tester.pumpAndSettle();

      // Tap Continue to proceed to Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Now on Step 2: Vehicle Information & Photos
      expect(find.text('Vehicle Information & Photos'), findsOneWidget);
      expect(find.text('Traditional Tricycle'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Tricycle Color'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Plate / Franchise No.'),
        findsOneWidget,
      );
      expect(find.text('OR/CR Document'), findsOneWidget);
      expect(find.text('OR/CR Expiry Date'), findsOneWidget);
      expect(find.text('Front Tricycle Photo'), findsOneWidget);
      expect(find.text('Back Tricycle Photo'), findsOneWidget);

      // Attempt to tap Continue without completing required vehicle fields or document uploads
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Confirm stays on Step 2 and displays snackbar message
      expect(find.text('Vehicle Information & Photos'), findsOneWidget);
      expect(
        find.text('Please complete all required vehicle text fields.'),
        findsOneWidget,
      );
    },
  );
}
