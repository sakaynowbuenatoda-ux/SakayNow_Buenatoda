import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/preferences/app_preferences_controller.dart';

class AdminUi {
  const AdminUi._();

  static const double maxContentWidth = 1280;
  static const double listContentWidth = 1040;
  static const double detailContentWidth = 760;
  static const double formContentWidth = 860;
  static const double sidebarWidth = 272;
  static const double collapsedSidebarWidth = 80;
  static const double appBarHeight = 72;
  static const double metricCardMinWidth = 144;
  static const double metricCardMaxWidth = 220;
  static const double metricCardSpacing = 12;

  static bool get isDarkMode => AppPreferencesController.instance.isDarkMode;

  static Color get background =>
      isDarkMode ? const Color(0xFF0B1018) : const Color(0xFFFFFFFF);
  static Color get surface =>
      isDarkMode ? const Color(0xFF121923) : const Color(0xFFFFFFFF);
  static Color get elevatedSurface =>
      isDarkMode ? const Color(0xFF17202C) : const Color(0xFFFFFFFF);
  static Color get mutedSurface =>
      isDarkMode ? const Color(0xFF1B2532) : const Color(0xFFF3F4F6);
  static Color get subtleSurface =>
      isDarkMode ? const Color(0xFF0F1620) : const Color(0xFFFAFAFA);
  static Color get border =>
      isDarkMode ? const Color(0xFF273548) : const Color(0xFFE1E4E8);
  static Color get strongBorder =>
      isDarkMode ? const Color(0xFF3A4A61) : const Color(0xFFCCD1D8);

  static Color get title =>
      isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get body =>
      isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF252B35);
  static Color get muted =>
      isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF596273);

  static Color get accent =>
      isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get success =>
      isDarkMode ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get warning =>
      isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get danger =>
      isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get neutral =>
      isDarkMode ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
  static Color get primary => accent;
  static Color get onPrimary => Colors.white;
  static Color get secondary => success;
  static Color get accentBlue => accent;
  static Color get highlightAmber => warning;
  static Color get successText => success;
  static Color get successBackground => soft(success, alpha: 0.12);
  static Color get dangerSoft => soft(danger, alpha: 0.10);
  static Color get warningSoft => soft(warning, alpha: 0.12);
  static Color get blueSoft => soft(accent, alpha: 0.10);

  static Color soft(Color color, {double alpha = 0.10}) {
    return color.withValues(alpha: isDarkMode ? alpha + 0.04 : alpha);
  }

  static BorderRadius get radius => BorderRadius.circular(9);
  static BorderRadius get cardRadius => BorderRadius.circular(12);

  /// Reserved for controls and cards that can be opened or activated.
  static List<BoxShadow> get interactiveShadow => <BoxShadow>[
    BoxShadow(
      color: const Color(
        0xFF0F172A,
      ).withValues(alpha: isDarkMode ? 0.26 : 0.055),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get interactiveHoverShadow => <BoxShadow>[
    BoxShadow(
      color: const Color(
        0xFF0F172A,
      ).withValues(alpha: isDarkMode ? 0.34 : 0.095),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Kept for small elevated UI such as unread badges.
  static List<BoxShadow> get cardShadow => interactiveShadow;

  static TextStyle get pageTitle => GoogleFonts.poppins(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.18,
    letterSpacing: -0.55,
  );

  static TextStyle get sectionTitle => GoogleFonts.poppins(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.25,
    letterSpacing: -0.25,
  );

  static TextStyle get cardTitle => GoogleFonts.poppins(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: title,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static TextStyle get labelText => GoogleFonts.poppins(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: muted,
    height: 1.3,
    letterSpacing: 0.1,
  );

  static TextStyle get bodyText => GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: body,
    height: 1.5,
  );

  static TextStyle get valueText => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.35,
    letterSpacing: -0.15,
  );

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1200
        ? 36.0
        : width >= 700
        ? 24.0
        : 16.0;

    return EdgeInsets.fromLTRB(
      horizontal,
      width >= 700 ? 24 : 16,
      horizontal,
      MediaQuery.of(context).viewPadding.bottom + 28,
    );
  }

  static double metricCardWidth(double maxWidth) {
    final availableWidth = maxWidth.isFinite ? maxWidth : metricCardMaxWidth;

    if (availableWidth <= 0) {
      return metricCardMinWidth;
    }

    if (availableWidth <= metricCardMinWidth) {
      return availableWidth;
    }

    var columns = (availableWidth / (metricCardMinWidth + metricCardSpacing))
        .floor();
    if (columns < 1) {
      columns = 1;
    } else if (columns > 5) {
      columns = 5;
    }

    final cardWidth =
        (availableWidth - (metricCardSpacing * (columns - 1))) / columns;

    if (cardWidth > metricCardMaxWidth) {
      return metricCardMaxWidth;
    }

    return cardWidth;
  }

  static InputDecoration inputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? labelText,
  }) {
    final outlineBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    );

    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surface,
      hintStyle: bodyText.copyWith(color: muted),
      labelStyle: bodyText.copyWith(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: outlineBorder,
      enabledBorder: outlineBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );
  }
}

class AdminPageContainer extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;

  const AdminPageContainer({
    super.key,
    required this.child,
    this.maxContentWidth = AdminUi.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminUi.background,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          builder: (context, value, animatedChild) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: animatedChild,
              ),
            );
          },
          child: SingleChildScrollView(
            padding: AdminUi.pagePadding(context),
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AdminSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AdminUi.surface,
        borderRadius: AdminUi.cardRadius,
        border: Border.all(color: AdminUi.border),
      ),
      child: child,
    );
  }
}

/// A clearly actionable surface with persistent elevation and hover feedback.
/// Passive information should use [AdminSurfaceCard] instead.
class AdminInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? accentColor;
  final String? semanticLabel;

  const AdminInteractiveCard({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.accentColor,
    this.semanticLabel,
  });

  @override
  State<AdminInteractiveCard> createState() => _AdminInteractiveCardState();
}

class _AdminInteractiveCardState extends State<AdminInteractiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AdminUi.accent;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.color ?? AdminUi.elevatedSurface,
        borderRadius: AdminUi.cardRadius,
        border: Border.all(
          color: _hovered
              ? accent.withValues(alpha: AdminUi.isDarkMode ? 0.60 : 0.38)
              : AdminUi.strongBorder,
        ),
        boxShadow: _hovered
            ? AdminUi.interactiveHoverShadow
            : AdminUi.interactiveShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AdminUi.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AdminUi.cardRadius,
          splashColor: accent.withValues(alpha: 0.08),
          hoverColor: accent.withValues(alpha: 0.035),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: card,
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool dense;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 16 : 20,
        vertical: dense ? 14 : 18,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dense ? AdminUi.sectionTitle : AdminUi.pageTitle,
                ),
                if (subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.bodyText,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry bodyPadding;

  const AdminSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      color: AdminUi.surface,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AdminUi.cardTitle.copyWith(
                          color: AdminUi.title,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AdminUi.bodyText.copyWith(
                            color: AdminUi.muted,
                            fontSize: 12.25,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AdminUi.border),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

class AdminDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool enableBack;
  final String backTooltip;

  const AdminDetailAppBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.onBack,
    this.enableBack = true,
    this.backTooltip = 'Back',
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AdminUi.surface,
      surfaceTintColor: AdminUi.surface,
      foregroundColor: AdminUi.title,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: preferredSize.height,
      shape: Border(bottom: BorderSide(color: AdminUi.border)),
      leading: IconButton(
        tooltip: backTooltip,
        onPressed: enableBack
            ? onBack ?? () => Navigator.of(context).pop()
            : null,
        icon: Icon(Icons.arrow_back_rounded, color: AdminUi.title),
      ),
      titleSpacing: 4,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdminUi.cardTitle.copyWith(
          color: AdminUi.title,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: actions,
    );
  }
}

class AdminCountPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String count;
  final String countLabel;
  final Color accentColor;

  const AdminCountPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.countLabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final countPill = Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminUi.subtleSurface,
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            count,
            style: AdminUi.valueText.copyWith(
              color: AdminUi.title,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            countLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.labelText.copyWith(
              color: AdminUi.body,
              fontSize: 10.75,
            ),
          ),
        ],
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AdminUi.pageTitle),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(subtitle, style: AdminUi.bodyText),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              titleBlock,
              const SizedBox(height: 12),
              countPill,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            countPill,
          ],
        );
      },
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const AdminStatusChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
