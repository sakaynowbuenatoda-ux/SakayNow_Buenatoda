import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'passenger_ui.dart';

class PassengerBookingHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget content;
  final String actionLabel;
  final IconData actionIcon;

  const PassengerBookingHeroCard({
    super.key,
    required this.onTap,
    required this.content,
    this.actionLabel = 'Book Now',
    this.actionIcon = Icons.navigation_rounded,
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
          SizedBox(
            width: double.infinity,
            height: compact ? 50 : 54,
            child: DecoratedBox(
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
                icon: Icon(actionIcon, size: 20),
                label: Text(
                  actionLabel,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
