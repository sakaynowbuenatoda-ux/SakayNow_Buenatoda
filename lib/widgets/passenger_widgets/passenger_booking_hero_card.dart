import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'passenger_ui.dart';

class PassengerBookingHeroCard extends StatefulWidget {
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
  State<PassengerBookingHeroCard> createState() =>
      _PassengerBookingHeroCardState();
}

class _PassengerBookingHeroCardState extends State<PassengerBookingHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.97, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final isDark = PassengerUi.isDarkMode;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  isDark ? const Color(0xFF111827) : Colors.white,
                  isDark ? const Color(0xFF0F1420) : const Color(0xFFF8F9FC),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E2536)
                    : const Color(0xFFE2E6EE),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: <Widget>[
                  // Subtle top accent line
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            isDark
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF030213),
                            isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563FF),
                            isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF16A34A),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 16,
                      compact ? 18 : 20,
                      compact ? 14 : 16,
                      compact ? 14 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        widget.content,
                        const SizedBox(height: 16),
                        _HeroActions(
                          primaryLabel: widget.actionLabel,
                          primaryIcon: widget.actionIcon,
                          onPrimaryTap: widget.onTap,
                          secondaryLabel: widget.secondaryActionLabel,
                          secondaryIcon: widget.secondaryActionIcon,
                          onSecondaryTap: widget.onSecondaryAction,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        height: compact ? 52 : 56,
        child: primaryButton,
      );
    }

    final secondaryButton = _SecondaryHeroButton(
      label: secondaryLabel!,
      icon: secondaryIcon ?? Icons.chat_bubble_rounded,
      onTap: onSecondaryTap!,
    );

    if (compact) {
      return Column(
        children: <Widget>[
          SizedBox(width: double.infinity, height: 52, child: primaryButton),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: secondaryButton,
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: SizedBox(height: 56, child: primaryButton)),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(height: 56, child: secondaryButton),
        ),
      ],
    );
  }
}

class _PrimaryHeroButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryHeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PrimaryHeroButton> createState() => _PrimaryHeroButtonState();
}

class _PrimaryHeroButtonState extends State<_PrimaryHeroButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final isDark = PassengerUi.isDarkMode;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = _pulseAnimation.value;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? <Color>[
                      Color.lerp(
                        const Color(0xFF1E293B),
                        const Color(0xFF2563EB),
                        pulseValue * 0.18,
                      )!,
                      Color.lerp(
                        const Color(0xFF111827),
                        const Color(0xFF1D4ED8),
                        pulseValue * 0.12,
                      )!,
                    ]
                  : <Color>[
                      Color.lerp(
                        const Color(0xFF020213),
                        const Color(0xFF111827),
                        pulseValue * 0.3,
                      )!,
                      const Color(0xFF030213),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (isDark
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF030213))
                    .withValues(alpha: 0.18 + (pulseValue * 0.06)),
                blurRadius: 12 + (pulseValue * 4),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ElevatedButton.icon(
        onPressed: widget.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(widget.icon, size: 20),
        label: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: compact ? 15 : 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _SecondaryHeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryHeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PassengerUi.isDarkMode;

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isDark ? const Color(0xFF2A3040) : const Color(0xFFD1D5DB),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
