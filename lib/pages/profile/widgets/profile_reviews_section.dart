import 'package:flutter/material.dart';

import '../../../widgets/app_skeleton.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../../../widgets/time_ago_text.dart';
import '../models/profile_review_item.dart';
import 'public_profile_components.dart';

typedef ProfileReviewsLoader = Stream<List<ProfileReviewItem>> Function();

class ProfileReviewsPreview extends StatelessWidget {
  final String title;
  final String profileName;
  final ProfileReviewsLoader reviewsLoader;
  final String emptyTitle;
  final String emptyDescription;
  final double? allReviewsMaxContentWidth;

  const ProfileReviewsPreview({
    super.key,
    required this.title,
    required this.profileName,
    required this.reviewsLoader,
    this.emptyTitle = 'No reviews yet',
    this.emptyDescription = 'Reviews from completed trips will appear here.',
    this.allReviewsMaxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileReviewItem>>(
      stream: reviewsLoader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppSkeletonCard(showAvatar: true, lineCount: 3);
        }

        if (snapshot.hasError) {
          return const PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load reviews',
            description: 'Reviews could not be loaded. Please try again.',
          );
        }

        final reviews = sortProfileReviews(
          snapshot.data ?? const <ProfileReviewItem>[],
        );
        final visibleReviews = reviews.take(3).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ProfileReviewsHeader(
              title: title,
              actionLabel: reviews.length > 3 ? 'See all reviews' : '',
              onActionTap: reviews.length > 3
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AllReviewsPage(
                          profileName: profileName,
                          reviewsLoader: reviewsLoader,
                          maxContentWidth: allReviewsMaxContentWidth,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            if (reviews.isEmpty)
              _CompactProfileEmptyState(
                icon: Icons.reviews_outlined,
                title: emptyTitle,
                description: emptyDescription,
              )
            else
              ...visibleReviews.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == visibleReviews.length - 1 ? 0 : 8,
                  ),
                  child: ProfileReviewCard(review: entry.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileReviewsHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;

  const _ProfileReviewsHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.sectionTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.25,
              ),
            ),
          ),
        ),
        if (actionLabel.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                color: PassengerUi.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactProfileEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _CompactProfileEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: PassengerUi.accentBlue),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PassengerUi.cardTitle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: PassengerUi.bodyText.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class AllReviewsPage extends StatefulWidget {
  final String profileName;
  final ProfileReviewsLoader reviewsLoader;
  final double? maxContentWidth;

  const AllReviewsPage({
    super.key,
    required this.profileName,
    required this.reviewsLoader,
    this.maxContentWidth,
  });

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  int? _selectedRating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: PublicProfileAppBar(
        title: 'Reviews',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: StreamBuilder<List<ProfileReviewItem>>(
        stream: widget.reviewsLoader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppSkeletonList(itemCount: 4);
          }

          if (snapshot.hasError) {
            return PassengerPageContainer(
              maxContentWidth: widget.maxContentWidth,
              child: const PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load reviews',
                description: 'Reviews could not be loaded. Please try again.',
              ),
            );
          }

          final reviews = sortProfileReviews(
            snapshot.data ?? const <ProfileReviewItem>[],
          );
          final filteredReviews = _selectedRating == null
              ? reviews
              : reviews
                    .where((review) => review.rating == _selectedRating)
                    .toList(growable: false);

          return PassengerPageContainer(
            maxContentWidth: widget.maxContentWidth,
            child: _AllReviewsContent(
              profileName: widget.profileName,
              allReviews: reviews,
              filteredReviews: filteredReviews,
              selectedRating: _selectedRating,
              onRatingSelected: (rating) =>
                  setState(() => _selectedRating = rating),
            ),
          );
        },
      ),
    );
  }
}

class _AllReviewsContent extends StatelessWidget {
  final String profileName;
  final List<ProfileReviewItem> allReviews;
  final List<ProfileReviewItem> filteredReviews;
  final int? selectedRating;
  final ValueChanged<int?> onRatingSelected;

  const _AllReviewsContent({
    required this.profileName,
    required this.allReviews,
    required this.filteredReviews,
    required this.selectedRating,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ReviewsPageHeading(profileName: profileName),
        const SizedBox(height: 10),
        _RatingFilters(
          selectedRating: selectedRating,
          onRatingSelected: onRatingSelected,
        ),
        const SizedBox(height: 9),
        Text(
          '${filteredReviews.length} ${filteredReviews.length == 1 ? 'review' : 'reviews'}',
          key: const Key('review-result-count'),
          style: PassengerUi.bodyText.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _ReviewsResult(
          allReviews: allReviews,
          filteredReviews: filteredReviews,
          selectedRating: selectedRating,
        ),
      ],
    );
  }
}

class _ReviewsPageHeading extends StatelessWidget {
  final String profileName;

  const _ReviewsPageHeading({required this.profileName});

  @override
  Widget build(BuildContext context) {
    final name = profileName.trim();
    final title = name.isEmpty
        ? 'All Reviews'
        : name.endsWith('s')
        ? '$name\' Reviews'
        : '$name\'s Reviews';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: PassengerUi.sectionTitle.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Icon(Icons.schedule_rounded, size: 13, color: PassengerUi.body),
            const SizedBox(width: 4),
            Text(
              'Most recent',
              style: PassengerUi.bodyText.copyWith(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingFilters extends StatelessWidget {
  final int? selectedRating;
  final ValueChanged<int?> onRatingSelected;

  const _RatingFilters({
    required this.selectedRating,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _RatingFilterChip(
          key: const Key('review-filter-all'),
          label: 'All',
          selected: selectedRating == null,
          onSelected: () => onRatingSelected(null),
        ),
        for (var rating = 1; rating <= 5; rating++)
          _RatingFilterChip(
            key: Key('review-filter-$rating'),
            label: '$rating',
            selected: selectedRating == rating,
            onSelected: () => onRatingSelected(rating),
          ),
      ],
    );
  }
}

class _RatingFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _RatingFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isAllFilter = label == 'All';
    final foregroundColor = selected ? Colors.white : PassengerUi.title;

    return ChoiceChip(
      label: isAllFilter
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: selected ? Colors.white : PassengerUi.highlightAmber,
                ),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: PassengerUi.dark,
      backgroundColor: PassengerUi.surface,
      side: BorderSide(color: selected ? PassengerUi.dark : PassengerUi.border),
      labelStyle: TextStyle(
        color: foregroundColor,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 7),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ReviewsResult extends StatelessWidget {
  final List<ProfileReviewItem> allReviews;
  final List<ProfileReviewItem> filteredReviews;
  final int? selectedRating;

  const _ReviewsResult({
    required this.allReviews,
    required this.filteredReviews,
    required this.selectedRating,
  });

  @override
  Widget build(BuildContext context) {
    if (allReviews.isEmpty) {
      return const _CompactProfileEmptyState(
        icon: Icons.reviews_outlined,
        title: 'No reviews yet',
        description: 'Reviews from completed trips will appear here.',
      );
    }

    if (filteredReviews.isEmpty) {
      return _CompactProfileEmptyState(
        icon: Icons.star_outline_rounded,
        title: 'No $selectedRating-star reviews',
        description: 'Choose another rating or select All to see every review.',
      );
    }

    return Column(
      children: filteredReviews
          .asMap()
          .entries
          .map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == filteredReviews.length - 1 ? 0 : 12,
              ),
              child: ProfileReviewCard(review: entry.value),
            );
          })
          .toList(growable: false),
    );
  }
}

class ProfileReviewCard extends StatelessWidget {
  final ProfileReviewItem review;

  const ProfileReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      key: ValueKey<String>('profile-review-${review.reviewId}'),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final identity = _ReviewIdentity(review: review);
              final stars = _ReviewStars(rating: review.rating);
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    identity,
                    const SizedBox(height: 6),
                    stars,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: identity),
                  const SizedBox(width: 8),
                  stars,
                ],
              );
            },
          ),
          if (review.comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 6),
          TimeAgoText(
            dateTime: review.updatedAt ?? review.createdAt,
            style: PassengerUi.bodyText.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _ReviewIdentity extends StatelessWidget {
  final ProfileReviewItem review;

  const _ReviewIdentity({required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          review.reviewerLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PassengerUi.cardTitle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (review.reviewerContext != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            review.reviewerContext!,
            style: PassengerUi.bodyText.copyWith(fontSize: 10.5),
          ),
        ],
      ],
    );
  }
}

class _ReviewStars extends StatelessWidget {
  final int rating;

  const _ReviewStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 15,
          color: PassengerUi.highlightAmber,
        ),
      ),
    );
  }
}
