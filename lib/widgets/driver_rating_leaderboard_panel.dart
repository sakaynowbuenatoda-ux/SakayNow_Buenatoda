import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/ride_tracking_service.dart';
import 'firebase_storage_image.dart';
import 'passenger_widgets/passenger_ui.dart';

const String _leaderboardAnimationAsset =
    'assets/animations/leaderboard_pulse.json';

class DriverRatingLeaderboardPanel extends StatelessWidget {
  final int limit;
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;
  final String? highlightDriverId;
  final bool showWeightedScore;
  final bool showIntro;
  final RideTrackingService rideTrackingService;

  DriverRatingLeaderboardPanel({
    super.key,
    this.limit = 5,
    this.title = 'Top Drivers',
    this.actionLabel = '',
    this.onActionTap,
    this.highlightDriverId,
    this.showWeightedScore = false,
    this.showIntro = true,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverReviewProfile>>(
      stream: rideTrackingService.watchTopDrivers(limit: limit),
      builder: (context, snapshot) {
        final header = PassengerSectionHeader(
          title: title,
          actionLabel: actionLabel,
          onActionTap: onActionTap,
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              const SizedBox(height: 12),
              if (showIntro) ...<Widget>[
                const _LeaderboardIntroCard(driverCount: 0, isLoading: true),
                const SizedBox(height: 12),
              ],
              const PassengerSurfaceCard(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              const SizedBox(height: 12),
              PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load leaderboard',
                description: snapshot.error.toString(),
              ),
            ],
          );
        }

        final drivers = snapshot.data ?? const <DriverReviewProfile>[];
        if (drivers.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              const SizedBox(height: 12),
              if (showIntro) ...<Widget>[
                const _LeaderboardIntroCard(driverCount: 0),
                const SizedBox(height: 12),
              ],
              const PassengerEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No ranked drivers yet',
                description:
                    'Driver rankings will appear after completed trip reviews.',
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            header,
            const SizedBox(height: 12),
            if (showIntro) ...<Widget>[
              _LeaderboardIntroCard(
                driverCount: drivers.length,
                showWeightedScore: showWeightedScore,
              ),
              const SizedBox(height: 12),
            ],
            ...drivers.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == drivers.length - 1 ? 0 : 12,
                ),
                child: _DriverLeaderboardTile(
                  driver: entry.value,
                  fallbackRank: entry.key + 1,
                  isHighlighted: entry.value.driverId == highlightDriverId,
                  showWeightedScore: showWeightedScore,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LeaderboardIntroCard extends StatelessWidget {
  final int driverCount;
  final bool showWeightedScore;
  final bool isLoading;

  const _LeaderboardIntroCard({
    required this.driverCount,
    this.showWeightedScore = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 12 : 14,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 62 : 72,
            height: compact ? 62 : 72,
            decoration: BoxDecoration(
              color: PassengerUi.warningSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Lottie.asset(
              _leaderboardAnimationAsset,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isLoading
                      ? 'Loading driver rankings'
                      : '${driverCount.clamp(0, 20)} ranked driver${driverCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle.copyWith(
                    fontSize: compact ? 15 : 16,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MetricPill(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Top 20',
                      color: PassengerUi.highlightAmber,
                    ),
                    _MetricPill(
                      icon: Icons.star_half_rounded,
                      label: showWeightedScore ? 'Rank score' : 'Reviews',
                      color: PassengerUi.accentBlue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverLeaderboardTile extends StatelessWidget {
  final DriverReviewProfile driver;
  final int fallbackRank;
  final bool isHighlighted;
  final bool showWeightedScore;

  const _DriverLeaderboardTile({
    required this.driver,
    required this.fallbackRank,
    required this.isHighlighted,
    required this.showWeightedScore,
  });

  @override
  Widget build(BuildContext context) {
    final rank = driver.ratingRank ?? fallbackRank;
    final accent = _rankColor(rank);
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Row(
        children: <Widget>[
          _RankBadge(
            rank: rank,
            fallbackLabel: driver.displayBadge,
            color: accent,
            isHighlighted: isHighlighted,
          ),
          SizedBox(width: compact ? 10 : 12),
          _DriverAvatar(driver: driver, color: accent),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        driver.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PassengerUi.cardTitle.copyWith(
                          fontSize: compact ? 14.5 : 15.5,
                        ),
                      ),
                    ),
                    if (isHighlighted) ...<Widget>[
                      const SizedBox(width: 8),
                      PassengerStatusChip(
                        label: 'You',
                        textColor: PassengerUi.successText,
                        backgroundColor: PassengerUi.successBackground,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _MetricPill(
                      icon: Icons.star_rounded,
                      label: driver.ratingLabel,
                      color: PassengerUi.highlightAmber,
                    ),
                    _MetricPill(
                      icon: Icons.rate_review_rounded,
                      label: driver.reviewCountLabel,
                      color: PassengerUi.accentBlue,
                    ),
                    if (showWeightedScore)
                      _MetricPill(
                        icon: Icons.trending_up_rounded,
                        label: 'Rank Score ${driver.weightedRatingLabel}',
                        color: PassengerUi.secondary,
                      ),
                    if (driver.displayBadge.isNotEmpty && rank > 20)
                      _MetricPill(
                        icon: Icons.military_tech_rounded,
                        label: driver.displayBadge,
                        color: PassengerUi.highlightAmber,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    return switch (rank) {
      1 => PassengerUi.highlightAmber,
      2 => PassengerUi.accentBlue,
      3 => PassengerUi.secondary,
      _ => PassengerUi.body,
    };
  }
}

class _DriverAvatar extends StatelessWidget {
  final DriverReviewProfile driver;
  final Color color;

  const _DriverAvatar({required this.driver, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      child: ClipOval(
        child: FirebaseStorageImage(
          imageUrl: driver.profileImageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(driver.fullName),
              style: PassengerUi.valueText.copyWith(
                color: PassengerUi.accentBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'D';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final String fallbackLabel;
  final Color color;
  final bool isHighlighted;

  const _RankBadge({
    required this.rank,
    required this.fallbackLabel,
    required this.color,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final label = rank >= 1 && rank <= 20
        ? '#$rank'
        : (fallbackLabel.isEmpty ? 'Ranked' : fallbackLabel);

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHighlighted
            ? PassengerUi.successBackground
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? PassengerUi.successText : color,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _rankIcon(rank),
            size: 16,
            color: isHighlighted ? PassengerUi.successText : color,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PassengerUi.valueText.copyWith(
              color: isHighlighted ? PassengerUi.successText : color,
              fontSize: label.length > 4 ? 9.5 : 12.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _rankIcon(int rank) {
    return switch (rank) {
      1 => Icons.emoji_events_rounded,
      2 => Icons.workspace_premium_rounded,
      3 => Icons.military_tech_rounded,
      _ => Icons.leaderboard_rounded,
    };
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PassengerUi.valueText.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
