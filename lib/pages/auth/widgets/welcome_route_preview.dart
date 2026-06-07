import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_ui.dart';

class WelcomeRoutePreview extends StatelessWidget {
  const WelcomeRoutePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AuthUi.border),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RouteGridPainter())),
          const Positioned(
            left: 16,
            top: 16,
            child: _MapTag(
              icon: Icons.my_location_rounded,
              label: 'Passenger pickup',
              color: AuthUi.accentBlue,
            ),
          ),
          const Positioned(
            right: 16,
            bottom: 16,
            child: _MapTag(
              icon: Icons.flag_rounded,
              label: 'Buenatoda terminal',
              color: AuthUi.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AuthUi.border.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePaint = Paint()
      ..color = AuthUi.accentBlue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.72)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.38,
        size.width * 0.58,
        size.height * 0.68,
        size.width * 0.72,
        size.height * 0.32,
      );
    canvas.drawPath(route, routePaint);

    final start = Offset(size.width * 0.18, size.height * 0.72);
    final end = Offset(size.width * 0.72, size.height * 0.32);
    canvas.drawCircle(start, 8, Paint()..color = AuthUi.accentBlue);
    canvas.drawCircle(end, 8, Paint()..color = AuthUi.secondary);
    canvas.drawCircle(
      start,
      14,
      Paint()..color = AuthUi.accentBlue.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      end,
      14,
      Paint()..color = AuthUi.secondary.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MapTag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: AuthUi.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AuthUi.title,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
