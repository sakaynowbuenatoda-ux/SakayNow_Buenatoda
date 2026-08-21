import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/app_skeleton.dart';
import 'package:sakaynow_buenatoda/pages/admin/admin_models.dart';
import 'package:sakaynow_buenatoda/pages/profile/models/profile_review_item.dart';
import 'package:sakaynow_buenatoda/pages/profile/widgets/profile_reviews_section.dart';

void main() {
  test('review items sort by effective date then review id', () {
    final sharedDate = DateTime(2026, 8, 10);
    final sorted = sortProfileReviews(<ProfileReviewItem>[
      _review('b', rating: 5, createdAt: sharedDate),
      _review('old', rating: 1, createdAt: DateTime(2026, 8, 1)),
      _review('a', rating: 4, createdAt: sharedDate),
      _review(
        'updated',
        rating: 3,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 8, 11),
      ),
    ]);

    expect(sorted.map((review) => review.reviewId), <String>[
      'updated',
      'a',
      'b',
      'old',
    ]);
  });

  test('admin reviews retain rating and reviewer-role context', () {
    final item = ProfileReviewItem.fromAdminReview(
      AdminReviewRecord(
        reviewId: 'admin-review',
        bookingId: 'booking-1',
        reviewerId: 'passenger-1',
        reviewerRole: 'passenger',
        revieweeId: 'driver-1',
        revieweeRole: 'driver',
        rating: 4,
        comment: 'Safe trip',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: null,
      ),
    );

    expect(item.reviewerLabel, '4/5 rating');
    expect(item.reviewerContext, 'Passenger review');
    expect(item.reviewerId, 'passenger-1');
    expect(item.bookingId, 'booking-1');
  });

  testWidgets('preview shows only three newest reviews and opens all reviews', (
    tester,
  ) async {
    final reviews = _reviews();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileReviewsPreview(
              title: 'Recent Reviews',
              profileName: 'Juan Dela Cruz',
              reviewsLoader: () => Stream.value(reviews),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-review-r5')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-review-r4')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-review-r3')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-review-r2')), findsNothing);
    expect(find.text('See all reviews'), findsOneWidget);

    await tester.tap(find.text('See all reviews'));
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz\'s Reviews'), findsOneWidget);
    expect(find.text('Most recent'), findsOneWidget);
    expect(find.byKey(const Key('review-result-count')), findsOneWidget);
    expect(find.text('5 reviews'), findsOneWidget);
    for (var rating = 1; rating <= 5; rating++) {
      expect(find.byKey(Key('review-filter-$rating')), findsOneWidget);
    }
  });

  testWidgets(
    'all reviews filters by one exact rating and keeps newest first',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllReviewsPage(
            profileName: 'Juan',
            reviewsLoader: () => Stream.value(_reviews()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('review-filter-3')));
      await tester.pumpAndSettle();

      expect(find.text('2 reviews'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-review-r5')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-review-r2')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-review-r4')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('profile-review-r5'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('profile-review-r2'))).dy,
        ),
      );

      await tester.tap(find.byKey(const Key('review-filter-4')));
      await tester.pumpAndSettle();
      expect(find.text('0 reviews'), findsOneWidget);
      expect(find.text('No 4-star reviews'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('5 reviews'), findsOneWidget);
    },
  );

  testWidgets('three-review preview has no all-reviews action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileReviewsPreview(
            title: 'Reviews',
            profileName: 'Passenger',
            reviewsLoader: () => Stream.value(_reviews().take(3).toList()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileReviewCard), findsNWidgets(3));
    expect(find.text('See all reviews'), findsNothing);
  });

  testWidgets('review pages render loading empty and error states', (
    tester,
  ) async {
    final controller = StreamController<List<ProfileReviewItem>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AllReviewsPage(
          profileName: 'Driver',
          reviewsLoader: () => controller.stream,
        ),
      ),
    );
    expect(find.byType(AppSkeletonList), findsOneWidget);

    controller.add(const <ProfileReviewItem>[]);
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: AllReviewsPage(
          profileName: 'Driver',
          reviewsLoader: () => Stream.error(StateError('failed')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load reviews'), findsOneWidget);
  });

  testWidgets('all reviews fits a compact phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AllReviewsPage(
          profileName: 'Passenger',
          reviewsLoader: () => Stream.value(_reviews()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-filter-5')), findsOneWidget);
    expect(find.byType(ProfileReviewCard), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });
}

List<ProfileReviewItem> _reviews() {
  return <ProfileReviewItem>[
    _review('r1', rating: 5, createdAt: DateTime(2026, 8, 1)),
    _review('r2', rating: 3, createdAt: DateTime(2026, 8, 2)),
    _review('r3', rating: 5, createdAt: DateTime(2026, 8, 3)),
    _review('r4', rating: 1, createdAt: DateTime(2026, 8, 4)),
    _review('r5', rating: 3, createdAt: DateTime(2026, 8, 5)),
  ];
}

ProfileReviewItem _review(
  String id, {
  required int rating,
  required DateTime createdAt,
  DateTime? updatedAt,
}) {
  return ProfileReviewItem(
    reviewId: id,
    reviewerLabel: 'Reviewer $id',
    rating: rating,
    comment: 'Review $id',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
