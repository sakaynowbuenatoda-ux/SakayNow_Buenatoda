import 'package:flutter/material.dart';

class AnimatedTabSwitcher extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  const AnimatedTabSwitcher({
    super.key,
    required this.index,
    required this.children,
    this.onRefresh,
  });

  @override
  State<AnimatedTabSwitcher> createState() => _AnimatedTabSwitcherState();
}

class _AnimatedTabSwitcherState extends State<AnimatedTabSwitcher> {
  final Set<int> _mountedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _trackCurrentIndex();
  }

  @override
  void didUpdateWidget(covariant AnimatedTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _trackCurrentIndex();
    _mountedIndexes.removeWhere((index) => index >= widget.children.length);
  }

  void _trackCurrentIndex() {
    if (widget.index >= 0 && widget.index < widget.children.length) {
      _mountedIndexes.add(widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mountedEntries = widget.children
        .asMap()
        .entries
        .where((entry) => _mountedIndexes.contains(entry.key))
        .toList(growable: false);
    mountedEntries.sort((a, b) {
      if (a.key == widget.index) {
        return 1;
      }
      if (b.key == widget.index) {
        return -1;
      }
      return a.key.compareTo(b.key);
    });

    final tabBody = Stack(
      fit: StackFit.expand,
      children: mountedEntries
          .map((entry) {
            final isSelected = entry.key == widget.index;

            return _PersistentTabSlot(
              key: ValueKey<int>(entry.key),
              isSelected: isSelected,
              child: entry.value,
            );
          })
          .toList(growable: false),
    );

    if (widget.onRefresh == null) {
      return tabBody;
    }

    return RefreshIndicator.adaptive(
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: widget.onRefresh!,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.vertical && notification.depth == 0,
      child: tabBody,
    );
  }
}

class _PersistentTabSlot extends StatelessWidget {
  final bool isSelected;
  final Widget child;

  const _PersistentTabSlot({
    super.key,
    required this.isSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Offstage(
        offstage: !isSelected,
        child: TickerMode(
          enabled: isSelected,
          child: ExcludeSemantics(excluding: !isSelected, child: child),
        ),
      ),
    );
  }
}
