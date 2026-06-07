import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_ui.dart';
import 'welcome_route_preview.dart';

class WelcomeProductPreview extends StatelessWidget {
  final bool compact;

  const WelcomeProductPreview({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: AuthUi.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PreviewHeader(),
          SizedBox(height: compact ? 16 : 18),
          SizedBox(
            height: compact ? 184 : 220,
            child: const WelcomeRoutePreview(),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _PreviewMetric(value: 'Book', label: 'Passenger'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _PreviewMetric(value: 'Accept', label: 'Driver'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AuthUi.border),
          const SizedBox(height: 14),
          const _PreviewTask(
            icon: Icons.pin_drop_rounded,
            title: 'Pickup and drop-off details',
            subtitle: 'Clear trip information before dispatch',
          ),
          const SizedBox(height: 12),
          const _PreviewTask(
            icon: Icons.timeline_rounded,
            title: 'Live ride status',
            subtitle: 'Track each booking from queue to completed',
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AuthUi.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.bolt_rounded, color: AuthUi.accentBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride operations',
                style: GoogleFonts.poppins(
                  color: AuthUi.title,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Booking and driver queue',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AuthUi.body,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const _LiveBadge(),
      ],
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String value;
  final String label;

  const _PreviewMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AuthUi.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AuthUi.title,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AuthUi.body,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTask extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PreviewTask({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AuthUi.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AuthUi.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AuthUi.title,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AuthUi.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AuthUi.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AuthUi.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Live',
            style: GoogleFonts.poppins(
              color: AuthUi.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
