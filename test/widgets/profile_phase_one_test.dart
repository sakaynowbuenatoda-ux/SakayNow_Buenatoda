import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/profile/models/profile_view_data.dart';
import 'package:sakaynow_buenatoda/pages/profile/widgets/profile_details_link_card.dart';
import 'package:sakaynow_buenatoda/pages/profile/widgets/profile_hero_card.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('minimal profile preserves identity and driver statistics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var avatarTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ProfileHeroCard(
                profile: _driverProfile(),
                onAvatarTap: () => avatarTapCount += 1,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('juan@example.com'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Average Rating'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Rank'), findsOneWidget);
    expect(find.text('Rank Score'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    final identitySection = tester.widget<Container>(
      find.byKey(const Key('profile-hero-identity')),
    );
    expect(
      (identitySection.decoration! as BoxDecoration).color,
      PassengerUi.dark,
    );
    expect(
      tester.widget<Text>(find.text('Juan Dela Cruz')).style?.color,
      Colors.white,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Change profile picture'));
    expect(avatarTapCount, 1);
  });

  testWidgets('minimal profile fits a wide layout without losing content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 760,
              child: ProfileHeroCard(profile: _driverProfile()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('4.62'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile action rows open details and settings', (tester) async {
    var detailsTapCount = 0;
    var settingsTapCount = 0;

    await tester.pumpWidget(
      _actionHost(
        onDetails: () => detailsTapCount += 1,
        onSettings: () => settingsTapCount += 1,
        onLogout: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('profile-details-action')));
    await tester.tap(find.byKey(const Key('profile-settings-action')));

    expect(detailsTapCount, 1);
    expect(settingsTapCount, 1);
  });

  testWidgets('profile action list uses bare dark icons without dividers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _actionHost(onDetails: () {}, onSettings: () {}, onLogout: () async {}),
    );

    expect(find.byType(Divider), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    for (final key in <Key>[
      const Key('profile-details-action'),
      const Key('profile-settings-action'),
      const Key('profile-logout-action'),
    ]) {
      final leadingIcon = tester
          .widgetList<Icon>(
            find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
          )
          .first;
      expect(leadingIcon.color, PassengerUi.dark);
    }
  });

  testWidgets('embedded admin action list omits Settings and Logout', (
    tester,
  ) async {
    await tester.pumpWidget(_actionHost(onDetails: () {}));

    expect(find.byKey(const Key('profile-details-action')), findsOneWidget);
    expect(find.byKey(const Key('profile-settings-action')), findsNothing);
    expect(find.byKey(const Key('profile-logout-action')), findsNothing);
  });

  testWidgets('logout cancellation does not call sign out', (tester) async {
    var logoutCount = 0;

    await tester.pumpWidget(
      _actionHost(onDetails: () {}, onLogout: () async => logoutCount += 1),
    );

    await tester.tap(find.byKey(const Key('profile-logout-action')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Logout'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(logoutCount, 0);
  });

  testWidgets('logout confirms once and displays progress until complete', (
    tester,
  ) async {
    final completer = Completer<void>();
    var logoutCount = 0;

    await tester.pumpWidget(
      _actionHost(
        onDetails: () {},
        onLogout: () {
          logoutCount += 1;
          return completer.future;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('profile-logout-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pump();

    expect(logoutCount, 1);
    expect(find.byKey(const Key('profile-logout-progress')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-logout-action')));
    await tester.pump();
    expect(logoutCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-logout-progress')), findsNothing);
  });

  testWidgets('logout failure is surfaced and unlocks the action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _actionHost(
        onDetails: () {},
        onLogout: () async => throw StateError('Sign out failed.'),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-logout-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out failed.'), findsOneWidget);
    expect(find.byKey(const Key('profile-logout-progress')), findsNothing);
  });
}

Widget _actionHost({
  required VoidCallback onDetails,
  VoidCallback? onSettings,
  Future<void> Function()? onLogout,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ProfileActionList(
          onProfileDetailsTap: onDetails,
          onSettingsTap: onSettings,
          onLogout: onLogout,
        ),
      ),
    ),
  );
}

ProfileViewData _driverProfile() {
  return ProfileViewData(
    userId: 'driver-1',
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    email: 'juan@example.com',
    role: 'driver',
    passengerType: '',
    gender: 'male',
    age: '32',
    isVerified: true,
    profilePictureUrl: null,
    profilePicturePath: null,
    profilePictureUpdatedAt: null,
    idImageUrl: null,
    selfieUrl: null,
    nbiClearanceUrl: null,
    driversLicenseUrl: null,
    vehicleType: 'Tricycle',
    tricycleColor: 'Blue',
    plateNumber: 'ABC-123',
    orCrUrl: null,
    tricycleFrontUrl: null,
    tricycleBackUrl: null,
    createdAt: Timestamp.fromDate(DateTime(2025)),
    averageRating: 4.8,
    reviewCount: 27,
    weightedRating: 4.62,
    ratingRank: 4,
    ratingBadge: 'Top Rated',
  );
}
