import 'package:flutter/material.dart';

import '../../../services/ride_tracking_service.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../../../widgets/time_ago_text.dart';
import '../models/profile_view_data.dart';

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
    return StreamBuilder<List<DriverReviewRecord>>(
      stream: rideTrackingService.watchUserReviews(profile.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load reviews',
            description: snapshot.error.toString(),
          );
        }

        final reviews = snapshot.data ?? const <DriverReviewRecord>[];
        if (reviews.isEmpty) {
          return const PassengerEmptyState(
            icon: Icons.reviews_outlined,
            title: 'No reviews yet',
            description: 'Reviews from completed trips will appear here.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Reviews', style: PassengerUi.sectionTitle),
            const SizedBox(height: 12),
            ...reviews.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == reviews.length - 1 ? 0 : 12,
                ),
                child: _ReviewTile(review: entry.value),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final DriverReviewRecord review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  review.reviewerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle.copyWith(fontSize: 14.5),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 16,
                    color: PassengerUi.highlightAmber,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(review.comment, style: PassengerUi.bodyText),
          ],
          const SizedBox(height: 8),
          TimeAgoText(
            dateTime: review.updatedAt ?? review.createdAt,
            style: PassengerUi.bodyText.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
