import 'package:flutter/material.dart';

import '../../../services/ride_tracking_service.dart';
import '../models/profile_review_item.dart';
import '../models/profile_view_data.dart';
import 'profile_reviews_section.dart';

class ProfileReviewsCard extends StatelessWidget {
  final ProfileViewData profile;
  final RideTrackingService rideTrackingService;

  ProfileReviewsCard({
    super.key,
    required this.profile,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    return ProfileReviewsPreview(
      title: 'Reviews',
      profileName: profile.fullName,
      reviewsLoader: () => rideTrackingService
          .watchUserReviews(profile.userId)
          .map(
            (reviews) => reviews
                .map(ProfileReviewItem.fromRideReview)
                .toList(growable: false),
          ),
    );
  }
}
