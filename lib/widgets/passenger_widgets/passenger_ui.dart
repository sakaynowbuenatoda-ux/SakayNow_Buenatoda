import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PassengerUi {
  const PassengerUi._();

  static const Color background = Color(0xFFF5FBFF);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFD8E7F2);
  static const Color primary = Color(0xFF0B63C8);
  static const Color secondary = Color(0xFF139A43);
  static const Color title = Color(0xFF0C2238);
  static const Color body = Color(0xFF567085);

  static BorderRadius get cardRadius => BorderRadius.circular(20);

  static List<BoxShadow> get cardShadow => <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF0C2238).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static TextStyle get sectionTitle => GoogleFonts.archivoBlack(
        fontSize: 18,
        color: title,
      );

  static TextStyle get cardTitle => GoogleFonts.archivoBlack(
        fontSize: 16,
        color: title,
      );

  static TextStyle get bodyText => GoogleFonts.inter(
        fontSize: 14,
        color: body,
        height: 1.4,
      );

  static TextStyle get valueText => GoogleFonts.inter(
        fontSize: 14,
        color: title,
        fontWeight: FontWeight.w700,
      );
}

class PassengerPageContainer extends StatelessWidget {
  final Widget child;

  const PassengerPageContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PassengerUi.background,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: child,
        ),
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
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        Expanded(
          child: Text(
            title,
            style: PassengerUi.sectionTitle,
          ),
        ),
        if (actionLabel.isNotEmpty)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                color: PassengerUi.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class PassengerStatusChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const PassengerStatusChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
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
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: PassengerUi.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: PassengerUi.bodyText),
                const SizedBox(height: 4),
                Text(value, style: PassengerUi.cardTitle),
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
              color: const Color(0xFFE6F3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: PassengerUi.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: PassengerUi.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
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
