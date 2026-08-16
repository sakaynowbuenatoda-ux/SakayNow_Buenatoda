import 'package:flutter/material.dart';

import '../pages/profile/driver_profile.dart';
import '../services/ride_tracking_service.dart';
import 'firebase_storage_image.dart';
import 'passenger_widgets/passenger_ui.dart';

class DriverRatingLeaderboardPanel extends StatelessWidget {
  final int limit;
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;
  final String? highlightDriverId;
  final bool showPodium;
  final bool compactPodium;
  final RideTrackingService rideTrackingService;

  DriverRatingLeaderboardPanel({
    super.key,
    this.limit = 20,
    this.title = 'Top Drivers',
    this.actionLabel = '',
    this.onActionTap,
    this.highlightDriverId,
    this.showPodium = true,
    this.compactPodium = false,
    RideTrackingService? rideTrackingService,
  }) : rideTrackingService = rideTrackingService ?? RideTrackingService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverReviewProfile>>(
      stream: rideTrackingService.watchTopDrivers(limit: limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[..._header(), const _LeaderboardLoadingState()],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ..._header(),
              const PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load leaderboard',
                description:
                    'Driver rankings could not be loaded. Please try again.',
              ),
            ],
          );
        }

        final drivers = snapshot.data ?? const <DriverReviewProfile>[];
        if (drivers.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ..._header(),
              const PassengerEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No ranked drivers yet',
                description:
                    'Driver rankings will appear after completed trip reviews.',
              ),
            ],
          );
        }

        final podiumCount = showPodium ? drivers.length.clamp(0, 3) : 0;
        final podiumDrivers = drivers.take(podiumCount).toList(growable: false);
        final listedDrivers = drivers.skip(podiumCount).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ..._header(),
            if (podiumDrivers.isNotEmpty)
              _LeaderboardPodium(
                drivers: podiumDrivers,
                highlightDriverId: highlightDriverId,
                compact: compactPodium,
                onDriverTap: (driver) => _openDriverProfile(context, driver),
              ),
            if (podiumDrivers.isNotEmpty && listedDrivers.isNotEmpty)
              const SizedBox(height: 18),
            if (listedDrivers.isNotEmpty)
              _LeaderboardList(
                drivers: listedDrivers,
                firstFallbackRank: podiumCount + 1,
                highlightDriverId: highlightDriverId,
                onDriverTap: (driver) => _openDriverProfile(context, driver),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _header() {
    if (title.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      PassengerSectionHeader(
        title: title,
        actionLabel: actionLabel,
        onActionTap: onActionTap,
      ),
      const SizedBox(height: 16),
    ];
  }

  void _openDriverProfile(BuildContext context, DriverReviewProfile driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverProfilePage(driverId: driver.driverId),
      ),
    );
  }
}

class _LeaderboardPodium extends StatelessWidget {
  final List<DriverReviewProfile> drivers;
  final String? highlightDriverId;
  final bool compact;
  final ValueChanged<DriverReviewProfile> onDriverTap;

  const _LeaderboardPodium({
    required this.drivers,
    required this.highlightDriverId,
    required this.compact,
    required this.onDriverTap,
  });

  @override
  Widget build(BuildContext context) {
    final podiumItems = drivers
        .asMap()
        .entries
        .map(
          (entry) => _PodiumDriver(
            driver: entry.value,
            fallbackRank: entry.key + 1,
            isHighlighted: entry.value.driverId == highlightDriverId,
            compact: compact,
            onTap: () => onDriverTap(entry.value),
          ),
        )
        .toList(growable: false);

    if (podiumItems.length == 1) {
      return KeyedSubtree(
        key: const Key('leaderboard-podium'),
        child: Center(child: SizedBox(width: 144, child: podiumItems.first)),
      );
    }

    return SizedBox(
      key: const Key('leaderboard-podium'),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (podiumItems.length >= 2)
            Expanded(child: podiumItems[1])
          else
            const Spacer(),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: compact ? 22 : 30),
              child: podiumItems[0],
            ),
          ),
          const SizedBox(width: 4),
          if (podiumItems.length >= 3)
            Expanded(child: podiumItems[2])
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _PodiumDriver extends StatelessWidget {
  final DriverReviewProfile driver;
  final int fallbackRank;
  final bool isHighlighted;
  final bool compact;
  final VoidCallback onTap;

  const _PodiumDriver({
    required this.driver,
    required this.fallbackRank,
    required this.isHighlighted,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rank = fallbackRank;
    final isWinner = rank == 1;
    final avatarSize = compact
        ? (isWinner ? 72.0 : 52.0)
        : (isWinner ? 86.0 : 62.0);
    final accent = _accentFor(context);
    final displayName = isHighlighted ? 'You' : driver.fullName;

    return Semantics(
      button: true,
      label:
          'Rank $rank, ${driver.fullName}, ${driver.ratingLabel} rating, '
          '${driver.reviewCountLabel}, ${driver.weightedRatingLabel} rank points',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('leaderboard-podium-rank-$rank'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              2,
              isWinner ? 0 : (compact ? 16 : 20),
              2,
              4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: avatarSize + 8,
                  height: avatarSize + (isWinner ? 25 : 17),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      if (isWinner)
                        Positioned(
                          top: 0,
                          child: CustomPaint(
                            size: compact
                                ? const Size(28, 19)
                                : const Size(32, 22),
                            painter: _CrownPainter(color: accent),
                          ),
                        ),
                      Positioned(
                        top: isWinner ? 18 : 0,
                        child: _LeaderboardAvatar(
                          key: Key('leaderboard-podium-avatar-$rank'),
                          driver: driver,
                          size: avatarSize,
                          borderColor: accent,
                          borderWidth: isWinner ? 3 : 2.5,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          key: Key('leaderboard-rank-badge-$rank'),
                          constraints: const BoxConstraints(minWidth: 24),
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: PassengerUi.background,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              color: _onAccentFor(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: PassengerUi.valueText.copyWith(
                    color: isHighlighted ? accent : PassengerUi.title,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                _PodiumMetric(
                  key: Key('leaderboard-review-count-${driver.driverId}'),
                  icon: Icons.star_rounded,
                  iconColor: accent,
                  label: '${driver.ratingLabel} · ${driver.reviewCountLabel}',
                ),
                const SizedBox(height: 2),
                _PodiumMetric(
                  key: Key('leaderboard-rank-points-${driver.driverId}'),
                  icon: Icons.trending_up_rounded,
                  iconColor: accent,
                  label: '${driver.weightedRatingLabel} rank pts',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PodiumMetric extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _PodiumMetric({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Icon(icon, size: 11, color: iconColor),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: PassengerUi.bodyText.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<DriverReviewProfile> drivers;
  final int firstFallbackRank;
  final String? highlightDriverId;
  final ValueChanged<DriverReviewProfile> onDriverTap;

  const _LeaderboardList({
    required this.drivers,
    required this.firstFallbackRank,
    required this.highlightDriverId,
    required this.onDriverTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('leaderboard-list'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: drivers
            .asMap()
            .entries
            .map((entry) {
              final fallbackRank = firstFallbackRank + entry.key;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == drivers.length - 1 ? 0 : 7,
                ),
                child: _LeaderboardRow(
                  driver: entry.value,
                  fallbackRank: fallbackRank,
                  isHighlighted: entry.value.driverId == highlightDriverId,
                  onTap: () => onDriverTap(entry.value),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final DriverReviewProfile driver;
  final int fallbackRank;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _LeaderboardRow({
    required this.driver,
    required this.fallbackRank,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rank = fallbackRank;
    final accent = _accentFor(context);
    final foreground = isHighlighted
        ? _onAccentFor(context)
        : PassengerUi.title;

    return Semantics(
      button: true,
      label:
          'Rank $rank, ${driver.fullName}, ${driver.ratingLabel} rating, '
          '${driver.reviewCountLabel}, ${driver.weightedRatingLabel} rank points',
      child: Material(
        key: Key('leaderboard-row-surface-$rank'),
        color: isHighlighted ? accent : PassengerUi.surface,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('leaderboard-row-$rank'),
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  _LeaderboardRankMarker(
                    rank: rank,
                    accent: accent,
                    foreground: foreground,
                    isHighlighted: isHighlighted,
                  ),
                  const SizedBox(width: 8),
                  _LeaderboardAvatar(
                    driver: driver,
                    size: 34,
                    borderColor: isHighlighted
                        ? foreground.withValues(alpha: 0.18)
                        : PassengerUi.border,
                    borderWidth: 1.5,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Text(
                      isHighlighted ? 'You' : driver.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.valueText.copyWith(
                        color: foreground,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${driver.weightedRatingLabel} pts',
                          key: Key(
                            'leaderboard-rank-points-${driver.driverId}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PassengerUi.valueText.copyWith(
                            color: foreground,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          key: Key(
                            'leaderboard-review-count-${driver.driverId}',
                          ),
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Icon(
                              Icons.star_rounded,
                              size: 10,
                              color: isHighlighted
                                  ? foreground.withValues(alpha: 0.72)
                                  : accent,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                '${driver.ratingLabel} · ${driver.reviewCountLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: PassengerUi.bodyText.copyWith(
                                  color: isHighlighted
                                      ? foreground.withValues(alpha: 0.72)
                                      : PassengerUi.body,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRankMarker extends StatelessWidget {
  final int rank;
  final Color accent;
  final Color foreground;
  final bool isHighlighted;

  const _LeaderboardRankMarker({
    required this.rank,
    required this.accent,
    required this.foreground,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    if (rank > 5) {
      return SizedBox(
        width: 26,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: PassengerUi.valueText.copyWith(
            color: foreground,
            fontSize: 12,
          ),
        ),
      );
    }

    final backgroundColor = isHighlighted ? foreground : accent;
    final textColor = isHighlighted ? accent : _onAccentFor(context);

    return Container(
      key: Key('leaderboard-list-rank-badge-$rank'),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: isHighlighted
            ? Border.all(color: foreground.withValues(alpha: 0.24))
            : null,
      ),
      child: Text(
        '$rank',
        style: PassengerUi.valueText.copyWith(
          color: textColor,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  final DriverReviewProfile driver;
  final double size;
  final Color borderColor;
  final double borderWidth;

  const _LeaderboardAvatar({
    super.key,
    required this.driver,
    required this.size,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: FirebaseStorageImage(
          imageUrl: driver.profileImageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: PassengerUi.mutedSurface,
            alignment: Alignment.center,
            child: Text(
              _initials(driver.fullName),
              style: PassengerUi.valueText.copyWith(
                color: PassengerUi.body,
                fontSize: size * 0.29,
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

class _CrownPainter extends CustomPainter {
  final Color color;

  const _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.23)
      ..lineTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.50, size.height * 0.05)
      ..lineTo(size.width * 0.72, size.height * 0.52)
      ..lineTo(size.width * 0.94, size.height * 0.23)
      ..lineTo(size.width * 0.84, size.height * 0.88)
      ..lineTo(size.width * 0.16, size.height * 0.88)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.15,
          size.height * 0.82,
          size.width * 0.70,
          size.height * 0.16,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _LeaderboardLoadingState extends StatelessWidget {
  const _LeaderboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 168,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: CircularProgressIndicator(color: _accentFor(context)),
    );
  }
}

Color _accentFor(BuildContext context) {
  return PassengerUi.isDarkMode ? Colors.white : Colors.black;
}

Color _onAccentFor(BuildContext context) {
  return PassengerUi.isDarkMode ? Colors.black : Colors.white;
}
