import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'passenger_ui.dart';

class PassengerBookingHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget content;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;

  const PassengerBookingHeroCard({
    super.key,
    required this.onTap,
    required this.content,
    this.actionLabel = 'Book Now',
    this.actionIcon = Icons.navigation_rounded,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          content,
          SizedBox(height: 16),
          _HeroActions(
            primaryLabel: actionLabel,
            primaryIcon: actionIcon,
            onPrimaryTap: onTap,
            secondaryLabel: secondaryActionLabel,
            secondaryIcon: secondaryActionIcon,
            onSecondaryTap: onSecondaryAction,
          ),
        ],
      ),
    );
  }
}

class _HeroActions extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimaryTap;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryTap;

  const _HeroActions({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimaryTap,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final primaryButton = _PrimaryHeroButton(
      label: primaryLabel,
      icon: primaryIcon,
      onTap: onPrimaryTap,
    );

    if (onSecondaryTap == null || secondaryLabel == null) {
      return SizedBox(
        width: double.infinity,
        height: compact ? 50 : 54,
        child: primaryButton,
      );
    }

    final secondaryButton = OutlinedButton.icon(
      onPressed: onSecondaryTap,
      icon: Icon(secondaryIcon ?? Icons.chat_bubble_rounded, size: 20),
      label: Text(
        secondaryLabel!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (compact) {
      return Column(
        children: <Widget>[
          SizedBox(width: double.infinity, height: 50, child: primaryButton),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 48, child: secondaryButton),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: SizedBox(height: 54, child: primaryButton)),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: SizedBox(height: 54, child: secondaryButton)),
      ],
    );
  }
}

class _PrimaryHeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryHeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: PassengerUi.darkActionGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: PassengerUi.cardShadow,
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: compact ? 15 : 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
