import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecentTripsSection extends StatelessWidget {
  final VoidCallback onViewAllTap;
  final VoidCallback? onSchoolTripTap;
  final VoidCallback? onHomeTripTap;

  const RecentTripsSection({
    super.key,
    required this.onViewAllTap,
    this.onSchoolTripTap,
    this.onHomeTripTap,
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
                'Recent Trips',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            GestureDetector(
              onTap: onViewAllTap,
              child: Text(
                'View all',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        RecentTripCard(
          destination: 'School',
          dateTimeText: 'Apr 1, 08:30 AM',
          fare: '₱20',
          rating: '5',
          onTap: onSchoolTripTap,
        ),
        const SizedBox(height: 12),
        RecentTripCard(
          destination: 'Home',
          dateTimeText: 'Mar 31, 04:00 PM',
          fare: '₱20',
          rating: '4',
          onTap: onHomeTripTap,
        ),
      ],
    );
  }
}



class RecentTripCard extends StatelessWidget {
  final String destination;
  final String dateTimeText;
  final String fare;
  final String rating;
  final VoidCallback? onTap;

  const RecentTripCard({
    super.key,
    required this.destination,
    required this.dateTimeText,
    required this.fare,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destination,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'completed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateTimeText,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    fare,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.star,
                  size: 16,
                  color: Color(0xFFF4B400),
                ),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}