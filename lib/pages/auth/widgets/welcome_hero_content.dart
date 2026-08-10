import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_ui.dart';
import 'auth_brand_header.dart';
import 'welcome_actions.dart';

class WelcomeHeroContent extends StatelessWidget {
  final bool compact;
  final bool centered;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const WelcomeHeroContent({
    super.key,
    required this.compact,
    required this.centered,
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = centered ? TextAlign.center : TextAlign.left;
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthBrandHeader(centered: centered),
        SizedBox(height: compact ? 24 : 34),
        const _SignalPill(),
        SizedBox(height: compact ? 16 : 20),
        Text(
          'Move around Buenavista with less waiting.',
          textAlign: textAlign,
          style: GoogleFonts.poppins(
            color: AuthUi.title,
            fontSize: compact ? 38 : 56,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: compact ? 14 : 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Book rides with one action, cashless payments, and real-time driver tracking.',
            textAlign: textAlign,
            style: GoogleFonts.poppins(
              color: AuthUi.body,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 28),
        WelcomeActions(
          compact: compact,
          centered: centered,
          onLogin: onLogin,
          onSignUp: onSignUp,
        ),
        SizedBox(height: compact ? 22 : 30),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 10,
          runSpacing: 10,
          children: const [
            _FeaturePill(icon: Icons.person_rounded, label: 'Passenger app'),
            _FeaturePill(icon: Icons.local_taxi_rounded, label: 'Driver queue'),
          ],
        ),
      ],
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: AuthUi.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_rounded, size: 16, color: AuthUi.secondary),
          const SizedBox(width: 8),
          Text(
            'Real-time tricycle booking',
            style: GoogleFonts.poppins(
              color: AuthUi.title,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: AuthUi.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AuthUi.accentBlue),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AuthUi.title,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
