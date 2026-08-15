import '../../../services/ride_tracking_service.dart';
import '../../admin/admin_models.dart';

class ProfileReviewItem {
  final String reviewId;
  final String reviewerLabel;
  final String? reviewerContext;
  final String bookingId;
  final String reviewerId;
  final String reviewerRole;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileReviewItem({
    required this.reviewId,
    required this.reviewerLabel,
    this.reviewerContext,
    this.bookingId = '',
    this.reviewerId = '',
    this.reviewerRole = '',
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileReviewItem.fromRideReview(DriverReviewRecord review) {
    return ProfileReviewItem(
      reviewId: review.reviewId,
      reviewerLabel: review.reviewerName,
      bookingId: review.bookingId,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    );
  }

  factory ProfileReviewItem.fromAdminReview(AdminReviewRecord review) {
    final roleLabel = _roleLabel(review.reviewerRole);

    return ProfileReviewItem(
      reviewId: review.reviewId,
      reviewerLabel: '${review.rating}/5 rating',
      reviewerContext: roleLabel.isEmpty ? null : '$roleLabel review',
      bookingId: review.bookingId,
      reviewerId: review.reviewerId,
      reviewerRole: review.reviewerRole,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    );
  }

  DateTime get effectiveDate =>
      updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  static String _roleLabel(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

List<ProfileReviewItem> sortProfileReviews(
  Iterable<ProfileReviewItem> reviews,
) {
  final sorted = reviews.toList(growable: false);
  sorted.sort((a, b) {
    final dateComparison = b.effectiveDate.compareTo(a.effectiveDate);
    if (dateComparison != 0) {
      return dateComparison;
    }

    return a.reviewId.compareTo(b.reviewId);
  });
  return sorted;
}
