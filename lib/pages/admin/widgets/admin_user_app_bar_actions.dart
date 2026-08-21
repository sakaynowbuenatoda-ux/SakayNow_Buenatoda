import 'package:flutter/material.dart';

import '../admin_models.dart';
import 'admin_message_user_button.dart';

class AdminUserAppBarActions extends StatelessWidget {
  final AdminUserRecord user;
  final String adminId;
  final bool isProcessing;
  final VoidCallback? onVerify;
  final VoidCallback? onRestrict;
  final VoidCallback? onRestore;

  const AdminUserAppBarActions({
    super.key,
    required this.user,
    required this.adminId,
    required this.isProcessing,
    this.onVerify,
    this.onRestrict,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showLabels = MediaQuery.sizeOf(context).width >= 760;
    final messageColor = isDark
        ? const Color(0xFF2563EB)
        : const Color(0xFF1D4ED8);
    final successColor = isDark
        ? const Color(0xFF059669)
        : const Color(0xFF047857);
    final dangerColor = isDark
        ? const Color(0xFFDC2626)
        : theme.colorScheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (user.isPassengerOrDriver && !user.isDeleted) ...<Widget>[
          AdminMessageUserButton(
            adminId: adminId,
            user: user,
            label: 'Message',
            enabled: !isProcessing,
            filled: true,
            showLabel: showLabels,
            tooltip: 'Message user',
            style: adminAppBarActionStyle(
              backgroundColor: messageColor,
              foregroundColor: Colors.white,
              showLabel: showLabels,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onVerify != null) ...<Widget>[
          _AdminUserAppBarActionButton(
            label: 'Verify User',
            tooltip: 'Verify user',
            icon: Icons.verified_user_rounded,
            color: successColor,
            showLabel: showLabels,
            onPressed: isProcessing ? null : onVerify,
          ),
          const SizedBox(width: 8),
        ],
        if (onRestore != null)
          _AdminUserAppBarActionButton(
            label: 'Restore Access',
            tooltip: 'Restore account access',
            icon: Icons.restart_alt_rounded,
            color: successColor,
            showLabel: showLabels,
            onPressed: isProcessing ? null : onRestore,
          )
        else if (onRestrict != null)
          _AdminUserAppBarActionButton(
            label: 'Restrict',
            tooltip: 'Restrict account',
            icon: Icons.block_rounded,
            color: dangerColor,
            showLabel: showLabels,
            onPressed: isProcessing ? null : onRestrict,
          ),
      ],
    );
  }
}

class _AdminUserAppBarActionButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final IconData icon;
  final Color color;
  final bool showLabel;
  final VoidCallback? onPressed;

  const _AdminUserAppBarActionButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.showLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = adminAppBarActionStyle(
      backgroundColor: color,
      foregroundColor: Colors.white,
      showLabel: showLabel,
    );
    final button = showLabel
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 17),
            label: Text(label),
          )
        : FilledButton(
            onPressed: onPressed,
            style: style,
            child: Icon(icon, size: 18),
          );

    return Tooltip(message: tooltip, child: button);
  }
}

ButtonStyle adminAppBarActionStyle({
  required Color backgroundColor,
  required Color foregroundColor,
  required bool showLabel,
}) {
  return FilledButton.styleFrom(
    minimumSize: Size(showLabel ? 0 : 40, 40),
    fixedSize: showLabel ? null : const Size.square(40),
    padding: EdgeInsets.symmetric(horizontal: showLabel ? 13 : 0),
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    disabledBackgroundColor: backgroundColor.withValues(alpha: 0.42),
    disabledForegroundColor: foregroundColor.withValues(alpha: 0.72),
    elevation: 0,
    shadowColor: backgroundColor.withValues(alpha: 0.28),
    textStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
  );
}

class AdminMissingDocumentsWarningPill extends StatelessWidget {
  const AdminMissingDocumentsWarningPill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFEAB308);
    final backgroundColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFFAFAFA)
        : const Color(0xFF111111);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Material(
        color: backgroundColor,
        elevation: isDark ? 8 : 5,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
        shape: StadiumBorder(side: BorderSide(color: warningColor, width: 1.2)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: warningColor, size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Some driver documents or vehicle details are missing or expired. Verify only after confirming the driver\'s identity.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
