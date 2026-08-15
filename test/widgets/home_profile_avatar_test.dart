import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/app_bar.dart';

void main() {
  for (final isDriver in <bool>[false, true]) {
    testWidgets(
      '${isDriver ? 'driver' : 'passenger'} home avatar opens Profile directly',
      (tester) async {
        var profileTapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeMapHeader(
                firstName: 'Juan',
                greeting: 'Welcome, Juan',
                isDriver: isDriver,
                showVerifiedBadge: true,
                onNotificationsTap: () {},
                onProfileTap: () => profileTapCount += 1,
              ),
            ),
          ),
        );

        expect(find.byType(PopupMenuButton), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        await tester.tap(find.byKey(const Key('home-profile-avatar-button')));
        await tester.pump();

        expect(profileTapCount, 1);
        expect(find.text('Profile'), findsNothing);
        expect(find.text('Settings'), findsNothing);
        expect(find.text('Logout'), findsNothing);
      },
    );
  }
}
