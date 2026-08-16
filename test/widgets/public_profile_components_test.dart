import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/profile/widgets/public_profile_components.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('public profile components stay aligned on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: PublicProfileAppBar(title: 'Driver Profile', onBack: () {}),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  PublicProfileHeroCard(
                    name: 'Juan Dela Cruz',
                    imageUrl: null,
                    fallbackInitial: 'D',
                    isVerified: true,
                    badges: <PublicProfileBadgeData>[
                      PublicProfileBadgeData(
                        label: 'Driver',
                        foregroundColor: PassengerUi.primary,
                        backgroundColor: PassengerUi.dangerSoft,
                      ),
                    ],
                    footer: const Text('Rank Score 4.38'),
                  ),
                  const SizedBox(height: 14),
                  PublicProfileStats(
                    metrics: <PublicProfileMetricData>[
                      PublicProfileMetricData(
                        icon: Icons.star_rounded,
                        label: 'Rating',
                        value: '5.0',
                        color: PassengerUi.highlightAmber,
                      ),
                      PublicProfileMetricData(
                        icon: Icons.reviews_outlined,
                        label: 'Reviews',
                        value: '12',
                        color: PassengerUi.accentBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Rank Score 4.38'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rating')).dy,
      tester.getTopLeft(find.text('Reviews')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile statistics stack when horizontal space is constrained', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: PublicProfileStats(
                metrics: <PublicProfileMetricData>[
                  PublicProfileMetricData(
                    icon: Icons.star_rounded,
                    label: 'Rating',
                    value: '4.9',
                    color: PassengerUi.highlightAmber,
                  ),
                  PublicProfileMetricData(
                    icon: Icons.reviews_outlined,
                    label: 'Reviews',
                    value: '18',
                    color: PassengerUi.accentBlue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Rating')).dy,
      lessThan(tester.getTopLeft(find.text('Reviews')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
