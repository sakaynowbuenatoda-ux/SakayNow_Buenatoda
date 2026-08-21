import 'package:flutter/material.dart';

/// Shared animated placeholders for asynchronous app content.
///
/// Keep one [AppSkeletonShimmer] around a group of shapes so the highlight
/// travels across the whole loading composition as a single surface.
class AppSkeletonShimmer extends StatefulWidget {
  final Widget child;
  final String semanticLabel;

  const AppSkeletonShimmer({
    super.key,
    required this.child,
    this.semanticLabel = 'Loading content',
  });

  @override
  State<AppSkeletonShimmer> createState() => _AppSkeletonShimmerState();
}

class _AppSkeletonShimmerState extends State<AppSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _SkeletonColors.fromTheme(Theme.of(context));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: reduceMotion
              ? ColorFiltered(
                  colorFilter: ColorFilter.mode(colors.base, BlendMode.srcIn),
                  child: widget.child,
                )
              : AnimatedBuilder(
                  animation: _controller,
                  child: widget.child,
                  builder: (context, child) {
                    final position = (_controller.value * 3) - 1.5;

                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(position - 1, 0),
                        end: Alignment(position + 1, 0),
                        colors: <Color>[
                          colors.base,
                          colors.highlight,
                          colors.base,
                        ],
                        stops: const <double>[0.25, 0.5, 0.75],
                      ).createShader(bounds),
                      child: child,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class AppSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
    );
  }
}

class AppSkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const AppSkeletonLine({super.key, this.width, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonBox(
      width: width,
      height: height,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
    );
  }
}

class AppSkeletonCircle extends StatelessWidget {
  final double diameter;

  const AppSkeletonCircle({super.key, this.diameter = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A compact skeleton that fits inside an existing card or section.
class AppSkeletonCard extends StatelessWidget {
  final bool showAvatar;
  final int lineCount;
  final double? height;
  final EdgeInsetsGeometry padding;

  const AppSkeletonCard({
    super.key,
    this.showAvatar = false,
    this.lineCount = 3,
    this.height,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeletonShimmer(
      child: Container(
        height: height,
        padding: padding,
        decoration: _surfaceDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showAvatar) ...const <Widget>[
              AppSkeletonCircle(),
              SizedBox(width: 12),
            ],
            Expanded(child: _SkeletonLines(lineCount: lineCount)),
          ],
        ),
      ),
    );
  }
}

/// Repeated rows used by trip, account, message, notification and report lists.
class AppSkeletonList extends StatelessWidget {
  final int itemCount;
  final bool showAvatar;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const AppSkeletonList({
    super.key,
    this.itemCount = 4,
    this.showAvatar = true,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(itemCount, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == itemCount - 1 ? 0 : spacing,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _surfaceDecoration(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showAvatar) ...const <Widget>[
                        AppSkeletonCircle(),
                        SizedBox(width: 12),
                      ],
                      const Expanded(child: _SkeletonLines(lineCount: 3)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Responsive dashboard placeholder for full-page initial loads.
class AppSkeletonPage extends StatelessWidget {
  final bool showHeader;
  final bool showMetrics;
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const AppSkeletonPage({
    super.key,
    this.showHeader = true,
    this.showMetrics = false,
    this.itemCount = 4,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final metricCount = isWide ? 4 : 2;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          child: AppSkeletonShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showHeader) ...const <Widget>[
                  AppSkeletonLine(width: 190, height: 20),
                  SizedBox(height: 10),
                  AppSkeletonLine(width: 270),
                  SizedBox(height: 20),
                ],
                if (showMetrics) ...<Widget>[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: metricCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.8 : 1.45,
                    ),
                    itemBuilder: (context, index) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _surfaceDecoration(context),
                      child: const _SkeletonLines(lineCount: 2),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                ...List<Widget>.generate(itemCount, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == itemCount - 1 ? 0 : 12,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _surfaceDecoration(context),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          AppSkeletonCircle(),
                          SizedBox(width: 12),
                          Expanded(child: _SkeletonLines(lineCount: 3)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppSkeletonProfile extends StatelessWidget {
  const AppSkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: AppSkeletonShimmer(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _surfaceDecoration(context),
              child: const Column(
                children: <Widget>[
                  AppSkeletonCircle(diameter: 88),
                  SizedBox(height: 16),
                  AppSkeletonLine(width: 180, height: 18),
                  SizedBox(height: 10),
                  AppSkeletonLine(width: 120),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...List<Widget>.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _surfaceDecoration(context),
                  child: const _SkeletonLines(lineCount: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLines extends StatelessWidget {
  final int lineCount;

  const _SkeletonLines({required this.lineCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(lineCount, (index) {
        final isLast = index == lineCount - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
          child: FractionallySizedBox(
            widthFactor: isLast ? 0.58 : (index.isEven ? 0.9 : 0.74),
            alignment: Alignment.centerLeft,
            child: AppSkeletonLine(height: index == 0 ? 14 : 11),
          ),
        );
      }),
    );
  }
}

BoxDecoration _surfaceDecoration(BuildContext context) {
  final theme = Theme.of(context);

  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
  );
}

class _SkeletonColors {
  final Color base;
  final Color highlight;

  const _SkeletonColors({required this.base, required this.highlight});

  factory _SkeletonColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return _SkeletonColors(
      base: isDark ? const Color(0xFF272B34) : const Color(0xFFE8EAF0),
      highlight: isDark ? const Color(0xFF3A404C) : const Color(0xFFF7F8FA),
    );
  }
}
