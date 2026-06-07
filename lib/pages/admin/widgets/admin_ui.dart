import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/preferences/app_preferences_controller.dart';

class AdminUi {
  const AdminUi._();

  static const double maxContentWidth = 1280;
  static const double listContentWidth = 1040;
  static const double detailContentWidth = 760;
  static const double formContentWidth = 860;
  static const double sidebarWidth = 268;
  static const double appBarHeight = 68;
  static const double metricCardMinWidth = 144;
  static const double metricCardMaxWidth = 220;
  static const double metricCardSpacing = 12;

  static bool get isDarkMode => AppPreferencesController.instance.isDarkMode;

  static Color get background =>
      isDarkMode ? const Color(0xFF0B0F17) : const Color(0xFFF6F7F9);
  static Color get surface =>
      isDarkMode ? const Color(0xFF121721) : const Color(0xFFFFFFFF);
  static Color get elevatedSurface =>
      isDarkMode ? const Color(0xFF171D29) : const Color(0xFFFFFFFF);
  static Color get mutedSurface =>
      isDarkMode ? const Color(0xFF1D2430) : const Color(0xFFF3F4F6);
  static Color get subtleSurface =>
      isDarkMode ? const Color(0xFF10151F) : const Color(0xFFFAFAFB);
  static Color get border =>
      isDarkMode ? const Color(0xFF263142) : const Color(0xFFE5E7EB);
  static Color get strongBorder =>
      isDarkMode ? const Color(0xFF334155) : const Color(0xFFD1D5DB);

  static Color get title =>
      isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  static Color get body => isDarkMode ? const Color(0xFFCBD5E1) : Colors.black;
  static Color get muted => isDarkMode ? const Color(0xFF94A3B8) : Colors.black;

  static Color get accent =>
      isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get success =>
      isDarkMode ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get warning =>
      isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get danger =>
      isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get neutral =>
      isDarkMode ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
  static Color get primary => neutral;
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

  static BorderRadius get radius => BorderRadius.circular(8);
  static BorderRadius get cardRadius => radius;

  static List<BoxShadow> get cardShadow => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: isDarkMode ? 0.26 : 0.035),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];

  static TextStyle get pageTitle => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.15,
  );

  static TextStyle get sectionTitle => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.25,
  );

  static TextStyle get cardTitle => GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.25,
  );

  static TextStyle get labelText => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: muted,
    height: 1.25,
  );

  static TextStyle get bodyText => GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: body,
    height: 1.45,
  );

  static TextStyle get valueText => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: title,
    height: 1.35,
  );

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1200
        ? 32.0
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.cardShadow,
      ),
      child: child,
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;
  final bool dense;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AdminUi.accent;

    return AdminSurfaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 14 : 16,
        vertical: dense ? 12 : 14,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: dense ? 34 : 38,
            height: dense ? 34 : 38,
            decoration: BoxDecoration(
              color: AdminUi.soft(color),
              borderRadius: AdminUi.radius,
            ),
            child: Icon(icon, color: color, size: dense ? 18 : 20),
          ),
          const SizedBox(width: 12),
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

class AdminCountPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String count;
  final String countLabel;
  final IconData icon;
  final Color accentColor;

  const AdminCountPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.countLabel,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AdminUi.soft(accentColor, alpha: 0.14),
              borderRadius: AdminUi.radius,
              border: Border.all(color: accentColor.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.sectionTitle,
                ),
                if (subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.bodyText.copyWith(color: AdminUi.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AdminUi.soft(accentColor, alpha: 0.10),
              borderRadius: AdminUi.radius,
              border: Border.all(color: accentColor.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  count,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AdminUi.valueText.copyWith(
                    color: accentColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AdminUi.labelText.copyWith(
                    color: AdminUi.body,
                    fontSize: 11,
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
