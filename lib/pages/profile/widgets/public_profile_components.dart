import 'package:flutter/material.dart';

import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';

class PublicProfileBadgeData {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const PublicProfileBadgeData({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

class PublicProfileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final VoidCallback onBack;

  const PublicProfileAppBar({
    super.key,
    required this.title,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(53);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: PassengerUi.surface,
      foregroundColor: PassengerUi.title,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 52,
      leading: IconButton(
        onPressed: onBack,
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded, size: 21),
      ),
      titleSpacing: 2,
      title: Text(
        title,
        style: TextStyle(
          color: PassengerUi.title,
          fontSize: 15.5,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: PassengerUi.border),
      ),
    );
  }
}

class PublicProfileHeroCard extends StatelessWidget {
  static const String _coverAssetPath = 'assets/images/full_logo.jpg';

  final String name;
  final String? imageUrl;
  final String fallbackInitial;
  final bool isVerified;
  final List<PublicProfileBadgeData> badges;
  final Widget? footer;

  const PublicProfileHeroCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.fallbackInitial,
    required this.isVerified,
    required this.badges,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final horizontalPadding = compact ? 14.0 : 16.0;
    final coverHeight = compact ? 86.0 : 104.0;
    final avatarSize = compact ? 68.0 : 78.0;

    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: PassengerUi.cardRadius,
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ProfileCover(height: coverHeight),
                Container(
                  width: double.infinity,
                  color: PassengerUi.surface,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    (avatarSize / 2) + 9,
                    horizontalPadding,
                    compact ? 14 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: PassengerUi.title,
                                  fontSize: compact ? 18 : 21,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.55,
                                ),
                              ),
                            ),
                            if (isVerified) ...<Widget>[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Verified profile',
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: compact ? 19 : 21,
                                  color: PassengerUi.accentBlue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (badges.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: badges
                              .map(
                                (badge) => PassengerStatusChip(
                                  label: badge.label,
                                  textColor: badge.foregroundColor,
                                  backgroundColor: badge.backgroundColor,
                                  dense: true,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      if (footer != null) ...<Widget>[
                        const SizedBox(height: 8),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: coverHeight - (avatarSize / 2),
              left: horizontalPadding,
              child: _PublicProfileAvatar(
                name: name,
                imageUrl: imageUrl,
                fallbackInitial: fallbackInitial,
                size: avatarSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCover extends StatelessWidget {
  final double height;

  const _ProfileCover({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            PublicProfileHeroCard._coverAssetPath,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.18),
            filterQuality: FilterQuality.medium,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfileAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String fallbackInitial;
  final double size;

  const _PublicProfileAvatar({
    required this.name,
    required this.imageUrl,
    required this.fallbackInitial,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$name profile picture',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: PassengerUi.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: PassengerUi.surface.withValues(alpha: 0.92),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: PassengerUi.isDarkMode ? 0.32 : 0.14,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: FirebaseStorageImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fallback: Container(
              color: PassengerUi.blueSoft,
              alignment: Alignment.center,
              child: Text(
                _initials(name, fallbackInitial),
                style: TextStyle(
                  color: PassengerUi.accentBlue,
                  fontSize: size * 0.29,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String value, String fallback) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return fallback;
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class PublicProfileMetricData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const PublicProfileMetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class PublicProfileStats extends StatelessWidget {
  final List<PublicProfileMetricData> metrics;

  const PublicProfileStats({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            children: metrics
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == metrics.length - 1 ? 0 : 8,
                    ),
                    child: PublicProfileMetricCard(metric: entry.value),
                  ),
                )
                .toList(growable: false),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: metrics
                .asMap()
                .entries
                .expand(
                  (entry) => <Widget>[
                    if (entry.key > 0) const SizedBox(width: 8),
                    Expanded(
                      child: PublicProfileMetricCard(metric: entry.value),
                    ),
                  ],
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

class PublicProfileMetricCard extends StatelessWidget {
  final PublicProfileMetricData metric;

  const PublicProfileMetricCard({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 28 : 31,
            height: compact ? 28 : 31,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              metric.icon,
              size: compact ? 16 : 18,
              color: metric.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PassengerUi.title,
              fontSize: compact ? 16 : 18,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PassengerUi.body,
              fontSize: compact ? 11 : 11.5,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
