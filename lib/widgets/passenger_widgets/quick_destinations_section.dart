import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickDestinationsSection extends StatelessWidget {
  final VoidCallback onSeeAllTap;
  final VoidCallback onHomeTap;
  final VoidCallback onSchoolTap;
  final VoidCallback onWorkTap;

  const QuickDestinationsSection({
    super.key,
    required this.onSeeAllTap,
    required this.onHomeTap,
    required this.onSchoolTap,
    required this.onWorkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick Destinations',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: onSeeAllTap,
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            QuickDestinationItem(
              label: 'Home',
              emoji: '🏠',
              circleColor: const Color(0xFFFFEAD5),
              onTap: onHomeTap,
            ),
            const SizedBox(width: 10),

            QuickDestinationItem(
              label: 'School',
              emoji: '🏫',
              circleColor: const Color(0xFFE3F7EA),
              onTap: onSchoolTap,
            ),
            const SizedBox(width: 10),

            QuickDestinationItem(
              label: 'Work',
              emoji: '💼',
              circleColor: const Color(0xFFEDE4FF),
              onTap: onWorkTap,
            ),
          ],
        ),
      ],
    );
  }
}

class QuickDestinationItem extends StatelessWidget {
  final String label;
  final String emoji;
  final Color circleColor;
  final VoidCallback onTap;

  const QuickDestinationItem({
    super.key,
    required this.label,
    required this.emoji,
    required this.circleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E5E5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: circleColor,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}