import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'passenger_ui.dart';

class PassengerBookingHeroCard extends StatelessWidget {
  final VoidCallback onTap;

  const PassengerBookingHeroCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFFE4F4FF),
                  Color(0xFFEAFBF0),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: PassengerUi.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: PassengerUi.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Book a Ride',
                        style: GoogleFonts.archivoBlack(
                          fontSize: 22,
                          color: PassengerUi.title,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Request a nearby tricycle with one tap, clear fares, and real-time trip updates.',
                        style: PassengerUi.bodyText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    PassengerUi.primary,
                    PassengerUi.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: Text(
                  'One-Tap Booking',
                  style: GoogleFonts.inter(
                    fontSize: 16,
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
