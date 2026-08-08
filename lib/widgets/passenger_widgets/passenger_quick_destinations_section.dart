import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerQuickDestinationsSection extends StatelessWidget {
  final List<PassengerQuickDestination> destinations;
  final VoidCallback onSeeAllTap;
  final ValueChanged<PassengerQuickDestination> onDestinationTap;

  const PassengerQuickDestinationsSection({
    super.key,
    required this.destinations,
    required this.onSeeAllTap,
    required this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (destinations.isEmpty)
          InkWell(
            borderRadius: PassengerUi.cardRadius,
            onTap: onSeeAllTap,
            child: const PassengerEmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'No saved destinations',
              description: 'Tap to add pickup and drop-off places.',
            ),
          )
        else
          PassengerQuickDestinationList(
            destinations: destinations,
            onDestinationTap: onDestinationTap,
          ),
      ],
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
      duration: Duration(
        milliseconds: 350 + (widget.destinations.length * 80),
      ),
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
        children: widget.destinations
            .asMap()
            .entries
            .map(
              (MapEntry<int, PassengerQuickDestination> entry) {
                final staggerStart =
                    (entry.key * 0.12).clamp(0.0, 0.7);
                final staggerEnd =
                    (staggerStart + 0.4).clamp(0.0, 1.0);

                final slideAnimation = Tween<Offset>(
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

                final fadeAnimation = Tween<double>(
                  begin: 0,
                  end: 1,
                ).animate(
                  CurvedAnimation(
                    parent: _staggerController,
                    curve: Interval(
                      staggerStart,
                      staggerEnd,
                      curve: Curves.easeOut,
                    ),
                  ),
                );

                return Padding(
                  padding: EdgeInsets.only(
                    right: entry.key == widget.destinations.length - 1
                        ? 0
                        : 10,
                  ),
                  child: SlideTransition(
                    position: slideAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: SizedBox(
                        width: _quickDestinationCardWidth(context),
                        child: PassengerQuickDestinationCard(
                          destination: entry.value,
                          onTap: () =>
                              widget.onDestinationTap(entry.value),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
            .toList(),
      ),
    );
  }
}

class PassengerQuickDestinationCard extends StatefulWidget {
  final PassengerQuickDestination destination;
  final VoidCallback onTap;

  const PassengerQuickDestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
  });

  @override
  State<PassengerQuickDestinationCard> createState() =>
      _PassengerQuickDestinationCardState();
}

class _PassengerQuickDestinationCardState
    extends State<PassengerQuickDestinationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.forward();
  void _onTapUp(TapUpDetails _) {
    _scaleController.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final destination = widget.destination;
    final isDark = PassengerUi.isDarkMode;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: compact ? 110 : 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                isDark
                    ? destination.backgroundColor.withValues(alpha: 0.10)
                    : destination.backgroundColor.withValues(alpha: 0.55),
                isDark
                    ? PassengerUi.surface
                    : destination.backgroundColor.withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? destination.accentColor.withValues(alpha: 0.18)
                  : destination.accentColor.withValues(alpha: 0.12),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: destination.accentColor.withValues(
                  alpha: isDark ? 0.08 : 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      destination.accentColor.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      destination.accentColor.withValues(
                        alpha: isDark ? 0.14 : 0.06,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: destination.accentColor.withValues(
                      alpha: isDark ? 0.24 : 0.15,
                    ),
                    width: 1.5,
                  ),
                ),
                child: destination.hasCustomEmoji
                    ? Center(
                        child: Text(
                          destination.customEmoji!,
                          style: TextStyle(fontSize: compact ? 22 : 24),
                        ),
                      )
                    : Icon(
                        destination.icon,
                        color: destination.accentColor,
                        size: compact ? 20 : 22,
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                destination.label,
                style: PassengerUi.cardTitle.copyWith(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  destination.locationDisplayLabel,
                  style: PassengerUi.bodyText.copyWith(
                    fontSize: compact ? 10.5 : 11,
                    color: PassengerUi.body.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _quickDestinationCardWidth(BuildContext context) {
  return PassengerUi.isCompactWidth(context) ? 132 : 146;
}
