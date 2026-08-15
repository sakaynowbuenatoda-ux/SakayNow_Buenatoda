import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../../../widgets/time_ago_text.dart';
import '../models/profile_review_item.dart';

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
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
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
            PassengerSectionHeader(
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
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              PassengerEmptyState(
                icon: Icons.reviews_outlined,
                title: emptyTitle,
                description: emptyDescription,
              )
            else
              ...visibleReviews.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == visibleReviews.length - 1 ? 0 : 12,
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
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Reviews', style: PassengerUi.cardTitle),
      ),
      body: StreamBuilder<List<ProfileReviewItem>>(
        stream: widget.reviewsLoader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
        const SizedBox(height: 16),
        _RatingFilters(
          selectedRating: selectedRating,
          onRatingSelected: onRatingSelected,
        ),
        const SizedBox(height: 14),
        Text(
          '${filteredReviews.length} ${filteredReviews.length == 1 ? 'review' : 'reviews'}',
          key: const Key('review-result-count'),
          style: PassengerUi.bodyText.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
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
        Text(title, style: PassengerUi.sectionTitle),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Icon(Icons.schedule_rounded, size: 16, color: PassengerUi.body),
            const SizedBox(width: 6),
            Text(
              'Most recent',
              style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
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
      spacing: 8,
      runSpacing: 8,
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
                  size: 15,
                  color: selected ? Colors.white : PassengerUi.highlightAmber,
                ),
                const SizedBox(width: 6),
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
        fontSize: 12.5,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
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
      return const PassengerEmptyState(
        icon: Icons.reviews_outlined,
        title: 'No reviews yet',
        description: 'Reviews from completed trips will appear here.',
      );
    }

    if (filteredReviews.isEmpty) {
      return PassengerEmptyState(
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
                    const SizedBox(height: 8),
                    stars,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: identity),
                  const SizedBox(width: 10),
                  stars,
                ],
              );
            },
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
          style: PassengerUi.cardTitle.copyWith(fontSize: 14.5),
        ),
        if (review.reviewerContext != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            review.reviewerContext!,
            style: PassengerUi.bodyText.copyWith(fontSize: 11.5),
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
          size: 17,
          color: PassengerUi.highlightAmber,
        ),
      ),
    );
  }
}
