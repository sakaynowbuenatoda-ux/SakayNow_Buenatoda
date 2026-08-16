import 'package:flutter/material.dart';
import '../../core/preferences/app_preferences_controller.dart';

class PassengerUi {
  const PassengerUi._();

  // Keeps the final page content above the floating navigation bar and its
  // center-docked action button when the shell extends beneath them.
  static const double pageBottomSpacing = 96;
  static const double settingsContentWidth = 760;

  static bool get isDarkMode => AppPreferencesController.instance.isDarkMode;

  static Color get background =>
      isDarkMode ? Color(0xFF09090B) : Color(0xFFFCFCFD);
  static Color get surface => isDarkMode ? Color(0xFF111318) : Colors.white;
  static Color get border => isDarkMode ? Color(0xFF262A33) : Color(0xFFE7E9EE);
  static Color get primary =>
      isDarkMode ? Color(0xFF60A5FA) : Color(0xFF030213);
  static Color get onPrimary => Colors.white;
  static Color get secondary =>
      isDarkMode ? Color(0xFF4ADE80) : Color(0xFF16A34A);
  static Color get accentBlue =>
      isDarkMode ? Color(0xFF60A5FA) : Color(0xFF2563FF);
  static Color get highlightAmber =>
      isDarkMode ? Color(0xFFFBBF24) : Color(0xFFF59E0B);
  static Color get title => isDarkMode ? Color(0xFFF9FAFB) : Color(0xFF0B0D18);
  static Color get body => isDarkMode ? Color(0xFFB6BBC6) : Color(0xFF667085);
  static Color get mutedSurface =>
      isDarkMode ? Color(0xFF1A1D24) : Color(0xFFF3F4F6);
  static Color get hint => isDarkMode ? Color(0xFF93C5FD) : Color(0xFF2563FF);
  static Color get dark => Color(0xFF030213);
  static Color get icon => isDarkMode ? Colors.white : dark;
  static Color get darkSoft =>
      isDarkMode ? Color(0xFF1F2430) : Color(0xFF111827);
  static Color get successBackground =>
      isDarkMode ? Color(0xFF053B2C) : Color(0xFFDCFCE7);
  static Color get successText =>
      isDarkMode ? Color(0xFF86EFAC) : Color(0xFF15803D);
  static Color get dangerSoft =>
      isDarkMode ? Color(0xFF451A1A) : Color(0xFFFFECEB);
  static Color get warningSoft =>
      isDarkMode ? Color(0xFF3F2E07) : Color(0xFFFEF3C7);
  static Color get blueSoft =>
      isDarkMode ? Color(0xFF172554) : Color(0xFFDBEAFE);

  static bool isCompactWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 390;

  static bool isNarrowWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static double horizontalPagePadding(BuildContext context) =>
      isNarrowWidth(context) ? 14 : 16;

  static BorderRadius get cardRadius => BorderRadius.circular(12);

  static List<BoxShadow> get cardShadow => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: isDarkMode ? 0.28 : 0.06),
      blurRadius: isDarkMode ? 14 : 14,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDarkMode ? 0.10 : 0.04),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static LinearGradient get darkActionGradient => LinearGradient(
    colors: <Color>[
      isDarkMode ? Color(0xFF2A3140) : Color(0xFF020213),
      isDarkMode ? Color(0xFF111318) : Color(0xFF030213),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get signalGradient => LinearGradient(
    colors: <Color>[
      isDarkMode ? Color(0xFF2563EB) : Color(0xFF020213),
      isDarkMode ? Color(0xFF60A5FA) : Color(0xFF202536),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get neutralHeroGradient => LinearGradient(
    colors: <Color>[
      isDarkMode ? Color(0xFF111318) : Color(0xFFFFFFFF),
      isDarkMode ? Color(0xFF1A1D24) : Color(0xFFF5F6F8),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get mapGradient => LinearGradient(
    colors: <Color>[
      isDarkMode ? Color(0xFF09090B) : Color(0xFFFFFFFF),
      isDarkMode ? Color(0xFF111318) : Color(0xFFF7F8FB),
      isDarkMode ? Color(0xFF1A1D24) : Color(0xFFF3F4F6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static TextStyle get sectionTitle =>
      TextStyle(fontSize: 18, color: title, fontWeight: FontWeight.w400);

  static TextStyle get cardTitle =>
      TextStyle(fontSize: 16, color: title, fontWeight: FontWeight.w400);

  static TextStyle get bodyText =>
      TextStyle(fontSize: 14, color: body, height: 1.4);

  static TextStyle get valueText =>
      TextStyle(fontSize: 14, color: title, fontWeight: FontWeight.w700);

  static double pageBottomInset(
    BuildContext context, {
    double baseSpacing = pageBottomSpacing,
  }) {
    return MediaQuery.of(context).viewPadding.bottom + baseSpacing;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double? horizontal,
    double top = 12,
    double baseBottom = 24,
  }) {
    final resolvedHorizontal = horizontal ?? horizontalPagePadding(context);
    return EdgeInsets.fromLTRB(
      resolvedHorizontal,
      top,
      resolvedHorizontal,
      baseBottom + pageBottomInset(context),
    );
  }
}

class PassengerPageContainer extends StatelessWidget {
  final Widget child;
  final double? maxContentWidth;

  const PassengerPageContainer({
    super.key,
    required this.child,
    this.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PassengerUi.background,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, animatedChild) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - value)),
                child: animatedChild,
              ),
            );
          },
          child: SingleChildScrollView(
            padding: PassengerUi.pagePadding(context),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: maxContentWidth == null
                ? child
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth!),
                      child: child,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class PassengerHomeSplitLayout extends StatefulWidget {
  final Widget map;
  final Widget header;
  final Widget child;
  final double maxContentWidth;

  const PassengerHomeSplitLayout({
    super.key,
    required this.map,
    required this.header,
    required this.child,
    this.maxContentWidth = 920,
  });

  @override
  State<PassengerHomeSplitLayout> createState() =>
      _PassengerHomeSplitLayoutState();
}

class _PassengerHomeSplitLayoutState extends State<PassengerHomeSplitLayout> {
  static const double _initialExtent = 0.5;
  static const double _expandedExtent = 2 / 3;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _sheetExtent = _initialExtent;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_handleSheetChanged);
  }

  @override
  void dispose() {
    _sheetController
      ..removeListener(_handleSheetChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSheetChanged() {
    if (!_sheetController.isAttached) {
      return;
    }

    final nextExtent = _sheetController.size;
    if ((nextExtent - _sheetExtent).abs() < 0.001 || !mounted) {
      return;
    }

    setState(() => _sheetExtent = nextExtent);
  }

  @override
  Widget build(BuildContext context) {
    final expansionProgress =
        ((_sheetExtent - _initialExtent) / (_expandedExtent - _initialExtent))
            .clamp(0.0, 1.0);

    return ColoredBox(
      color: PassengerUi.background,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          KeyedSubtree(key: const Key('home-map-pane'), child: widget.map),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: const Alignment(0, -0.08),
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 440),
            curve: Curves.easeOutCubic,
            builder: (context, entrance, child) {
              return Opacity(
                opacity: entrance * (1 - (expansionProgress * 0.08)),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (12 * (1 - entrance)) - (8 * expansionProgress),
                  ),
                  child: child,
                ),
              );
            },
            child: widget.header,
          ),
          Positioned.fill(
            child: DraggableScrollableSheet(
              key: const Key('home-content-sheet'),
              controller: _sheetController,
              initialChildSize: _initialExtent,
              minChildSize: _initialExtent,
              maxChildSize: _expandedExtent,
              expand: false,
              snap: true,
              snapSizes: const <double>[_initialExtent, _expandedExtent],
              snapAnimationDuration: const Duration(milliseconds: 360),
              builder: (context, scrollController) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.maxContentWidth,
                    ),
                    child: SizedBox.expand(
                      key: const Key('home-content-sheet-surface'),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: PassengerUi.background,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: PassengerUi.border.withValues(alpha: 0.9),
                            ),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: PassengerUi.isDarkMode ? 0.34 : 0.14,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          child: CustomScrollView(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: <Widget>[
                              SliverToBoxAdapter(
                                child: Center(
                                  child: Container(
                                    key: const Key('home-sheet-handle'),
                                    width: 42,
                                    height: 5,
                                    margin: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PassengerUi.body.withValues(
                                        alpha: 0.32,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: PassengerUi.pagePadding(
                                    context,
                                    top: 10,
                                  ),
                                  child: widget.child,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PassengerSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PassengerSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: PassengerUi.cardRadius,
        border: Border.all(color: PassengerUi.border),
        boxShadow: PassengerUi.cardShadow,
      ),
      child: child,
    );
  }
}

class PassengerSectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;

  const PassengerSectionHeader({
    super.key,
    required this.title,
    this.actionLabel = '',
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: PassengerUi.sectionTitle)),
        if (actionLabel.isNotEmpty)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionLabel,
              style: TextStyle(
                color: PassengerUi.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class PassengerPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;
  final bool dense;
  final bool showIcon;

  const PassengerPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor,
    this.dense = false,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return Semantics(
      container: true,
      header: true,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: PassengerUi.sectionTitle.copyWith(
            fontSize: dense || compact ? 20 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            height: 1.08,
          ),
        ),
      ),
    );
  }
}

class PassengerStatusChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool dense;

  const PassengerStatusChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class PassengerStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const PassengerStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: PassengerUi.accentBlue),
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText.copyWith(
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle.copyWith(
                    fontSize: compact ? 15 : 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PassengerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const PassengerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: PassengerUi.accentBlue),
          ),
          SizedBox(height: 14),
          Text(
            title,
            style: PassengerUi.cardTitle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: PassengerUi.bodyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
