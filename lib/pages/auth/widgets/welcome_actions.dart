import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_ui.dart';

class WelcomeActions extends StatelessWidget {
  final bool compact;
  final bool centered;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const WelcomeActions({
    super.key,
    required this.compact,
    required this.centered,
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    final loginButton = _ActionButton(
      label: 'Login',
      icon: Icons.login_rounded,
      onPressed: onLogin,
      filled: true,
    );
    final signUpButton = _ActionButton(
      label: 'Sign up',
      icon: Icons.person_add_alt_1_rounded,
      onPressed: onSignUp,
      filled: false,
    );

    if (compact) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: loginButton),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: signUpButton),
        ],
      );
    }

    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        SizedBox(width: 154, child: loginButton),
        const SizedBox(width: 12),
        SizedBox(width: 154, child: signUpButton),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );

    if (!filled) {
      return SizedBox(
        height: 54,
        child: OutlinedButton(onPressed: onPressed, child: child),
      );
    }

    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AuthUi.darkActionGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AuthUi.cardShadow,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
