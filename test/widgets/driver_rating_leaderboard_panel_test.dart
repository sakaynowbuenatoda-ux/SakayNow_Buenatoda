import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/preferences/app_preferences_controller.dart';
import 'package:sakaynow_buenatoda/services/ride_tracking_service.dart';
import 'package:sakaynow_buenatoda/widgets/driver_rating_leaderboard_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'uses a podium for the top three and keeps reviews and rank points visible',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AppPreferencesController.instance.setThemePreference(
        AppThemePreference.light,
      );
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestore = FakeFirebaseFirestore();
      await _seedDriver(
        firestore,
        id: 'driver-1',
        rank: 1,
        firstName: 'Bryan',
        lastName: 'Wolf',
        averageRating: 4.9,
        reviewCount: 58,
        rankPoints: 4.92,
      );
      await _seedDriver(
        firestore,
        id: 'driver-2',
        rank: 2,
        firstName: 'Meghan',
        lastName: 'James',
        averageRating: 4.8,
        reviewCount: 42,
        rankPoints: 4.81,
      );
      await _seedDriver(
        firestore,
        id: 'driver-3',
        rank: 3,
        firstName: 'Alex',
        lastName: 'Turner',
        averageRating: 4.7,
        reviewCount: 38,
        rankPoints: 4.73,
      );
      await _seedDriver(
        firestore,
        id: 'driver-4',
        rank: 4,
        firstName: 'Marsha',
        lastName: 'Fisher',
        averageRating: 4.7,
        reviewCount: 36,
        rankPoints: 4.66,
      );
      await _seedDriver(
        firestore,
        id: 'driver-5',
        rank: 5,
        firstName: 'Ricardo',
        lastName: 'Veum',
        averageRating: 4.6,
        reviewCount: 32,
        rankPoints: 4.6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DriverRatingLeaderboardPanel(
                title: '',
                highlightDriverId: 'driver-4',
                rideTrackingService: RideTrackingService(firestore: firestore),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leaderboard-podium')), findsOneWidget);
      expect(
        find.byKey(const Key('leaderboard-podium-rank-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('leaderboard-podium-rank-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('leaderboard-podium-rank-3')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('leaderboard-list')), findsOneWidget);
      expect(find.byKey(const Key('leaderboard-row-4')), findsOneWidget);
      expect(find.byKey(const Key('leaderboard-row-5')), findsOneWidget);

      final firstPlaceTop = tester
          .getTopLeft(find.byKey(const Key('leaderboard-podium-rank-1')))
          .dy;
      final secondPlaceTop = tester
          .getTopLeft(find.byKey(const Key('leaderboard-podium-rank-2')))
          .dy;
      expect(firstPlaceTop, lessThan(secondPlaceTop));

      final rankBadge = tester.widget<Container>(
        find.byKey(const Key('leaderboard-rank-badge-1')),
      );
      expect((rankBadge.decoration! as BoxDecoration).color, Colors.black);
      expect(
        tester
            .getSize(find.byKey(const Key('leaderboard-podium-avatar-1')))
            .width,
        86,
      );
      final highlightedSurface = tester.widget<Material>(
        find.byKey(const Key('leaderboard-row-surface-4')),
      );
      expect(highlightedSurface.color, Colors.black);
      final fourthPlaceBadge = tester.widget<Container>(
        find.byKey(const Key('leaderboard-list-rank-badge-4')),
      );
      final fifthPlaceBadge = tester.widget<Container>(
        find.byKey(const Key('leaderboard-list-rank-badge-5')),
      );
      expect(
        (fourthPlaceBadge.decoration! as BoxDecoration).color,
        Colors.white,
      );
      expect(
        (fifthPlaceBadge.decoration! as BoxDecoration).color,
        Colors.black,
      );

      expect(find.text('4.9 · 58 reviews'), findsOneWidget);
      expect(find.text('4.92 rank pts'), findsOneWidget);
      expect(find.text('4.7 · 36 reviews'), findsOneWidget);
      expect(find.text('4.66 pts'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    },
  );

  testWidgets('uses white leaderboard accents in dark mode', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferencesController.instance.setThemePreference(
      AppThemePreference.dark,
    );
    addTearDown(
      () => AppPreferencesController.instance.setThemePreference(
        AppThemePreference.light,
      ),
    );

    final service = _RecordingRideTrackingService();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: DriverRatingLeaderboardPanel(
            title: '',
            compactPodium: true,
            rideTrackingService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.requestedLimit, 20);
    final rankBadge = tester.widget<Container>(
      find.byKey(const Key('leaderboard-rank-badge-1')),
    );
    expect((rankBadge.decoration! as BoxDecoration).color, Colors.white);
    expect(
      tester
          .getSize(find.byKey(const Key('leaderboard-podium-avatar-1')))
          .width,
      72,
    );
  });
}

class _RecordingRideTrackingService extends RideTrackingService {
  int? requestedLimit;

  _RecordingRideTrackingService() : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<List<DriverReviewProfile>> watchTopDrivers({int limit = 5}) {
    requestedLimit = limit;
    return Stream<List<DriverReviewProfile>>.value(<DriverReviewProfile>[
      const DriverReviewProfile(
        driverId: 'driver-1',
        fullName: 'Juan Dela Cruz',
        isVerified: true,
        isActive: true,
        isBanned: false,
        profileImageUrl: null,
        averageRating: 5,
        reviewCount: 12,
        weightedRating: 4.38,
        ratingRank: 1,
        ratingBadge: '#1',
      ),
    ]);
  }
}

Future<void> _seedDriver(
  FakeFirebaseFirestore firestore, {
  required String id,
  required int rank,
  required String firstName,
  required String lastName,
  required double averageRating,
  required int reviewCount,
  required double rankPoints,
}) {
  return firestore.collection('users').doc(id).set(<String, dynamic>{
    'role': 'driver',
    'is_verified': true,
    'is_banned': false,
    'first_name': firstName,
    'last_name': lastName,
    'driver_average_rating': averageRating,
    'driver_review_count': reviewCount,
    'driver_weighted_rating': rankPoints,
    'driver_rating_rank': rank,
  });
}
