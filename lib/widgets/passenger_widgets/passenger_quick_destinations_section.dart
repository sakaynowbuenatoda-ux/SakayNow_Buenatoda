import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerQuickDestinationsSection extends StatelessWidget {
  final List<PassengerQuickDestination> destinations;
  final VoidCallback onSeeAllTap;
  final ValueChanged<PassengerQuickDestination> onDestinationTap;
  final String title;
  final String actionLabel;

  const PassengerQuickDestinationsSection({
    super.key,
    required this.destinations,
    required this.onSeeAllTap,
    required this.onDestinationTap,
    this.title = 'One-tap booking',
    this.actionLabel = 'View all',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _QuickDestinationsHeader(
          title: title,
          actionLabel: actionLabel,
          onActionTap: onSeeAllTap,
        ),
        const SizedBox(height: 12),
        if (destinations.isEmpty)
          _QuickDestinationsEmptyCard(onTap: onSeeAllTap)
        else
          PassengerQuickDestinationList(
            destinations: destinations,
            onDestinationTap: onDestinationTap,
          ),
      ],
    );
  }
}

class _QuickDestinationsHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;

  const _QuickDestinationsHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PassengerUi.sectionTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            foregroundColor: PassengerUi.accentBlue,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickDestinationsEmptyCard extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickDestinationsEmptyCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PassengerUi.surface,
      shape: RoundedRectangleBorder(
        borderRadius: PassengerUi.cardRadius,
        side: BorderSide(color: PassengerUi.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PassengerUi.blueSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmark_add_outlined,
                  color: PassengerUi.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'No saved destinations',
                      style: PassengerUi.cardTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap to add a place for faster booking.',
                      style: PassengerUi.bodyText.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: PassengerUi.body,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PassengerQuickDestinationList extends StatefulWidget {
  final List<PassengerQuickDestination> destinations;
  final ValueChanged<PassengerQuickDestination> onDestinationTap;

  const PassengerQuickDestinationList({
    super.key,
    required this.destinations,
    required this.onDestinationTap,
  });

  @override
  State<PassengerQuickDestinationList> createState() =>
      _PassengerQuickDestinationListState();
}

class _PassengerQuickDestinationListState
    extends State<PassengerQuickDestinationList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + (widget.destinations.length * 80)),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.destinations.isEmpty) {
      return const PassengerEmptyState(
        icon: Icons.bookmark_add_outlined,
        title: 'No saved destinations',
        description: 'Add a place to use it as a quick destination.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: widget.destinations.asMap().entries.map((
          MapEntry<int, PassengerQuickDestination> entry,
        ) {
          final staggerStart = (entry.key * 0.12).clamp(0.0, 0.7);
          final staggerEnd = (staggerStart + 0.4).clamp(0.0, 1.0);

          final slideAnimation =
              Tween<Offset>(
                begin: const Offset(0.35, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _staggerController,
                  curve: Interval(
                    staggerStart,
                    staggerEnd,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              );

          final fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _staggerController,
              curve: Interval(staggerStart, staggerEnd, curve: Curves.easeOut),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              right: entry.key == widget.destinations.length - 1 ? 0 : 10,
            ),
            child: SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: SizedBox(
                  width: _quickDestinationCardWidth(context),
                  child: PassengerQuickDestinationCard(
                    key: ValueKey<String>(
                      'quick-destination-card-${entry.value.id}',
                    ),
                    destination: entry.value,
                    onTap: () => widget.onDestinationTap(entry.value),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PassengerQuickDestinationCard extends StatelessWidget {
  final PassengerQuickDestination destination;
  final VoidCallback onTap;

  const PassengerQuickDestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final isDark = PassengerUi.isDarkMode;
    final resolvedAccent =
        isDark && destination.accentColor.computeLuminance() < 0.18
        ? PassengerUi.icon
        : destination.accentColor;

    return Material(
      color: PassengerUi.surface,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: PassengerUi.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: compact ? 134 : 146,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 10,
              compact ? 10 : 12,
              compact ? 8 : 10,
              9,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: compact ? 46 : 52,
                  height: compact ? 46 : 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? resolvedAccent.withValues(alpha: 0.14)
                        : destination.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: destination.hasCustomEmoji
                      ? Center(
                          child: Text(
                            destination.customEmoji!,
                            style: TextStyle(fontSize: compact ? 24 : 28),
                          ),
                        )
                      : Icon(
                          destination.icon,
                          color: resolvedAccent,
                          size: compact ? 22 : 25,
                        ),
                ),
                SizedBox(height: compact ? 8 : 10),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle.copyWith(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  destination.locationDisplayLabel,
                  style: PassengerUi.bodyText.copyWith(
                    fontSize: compact ? 9.5 : 10,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _quickDestinationCardWidth(BuildContext context) {
  return PassengerUi.isCompactWidth(context) ? 112 : 128;
}
