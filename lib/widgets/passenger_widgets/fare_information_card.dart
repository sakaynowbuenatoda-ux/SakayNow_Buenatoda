import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FareInformationCard extends StatelessWidget {
  const FareInformationCard({super.key});

  Widget _bulletText({
    required String label,
    required String value,
    Color valueColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB7D3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fare Information',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          _bulletText(label: 'Base fare: ', value: '₱30'),
          _bulletText(label: 'Per kilometer: ', value: '₱5'),
          _bulletText(label: 'Minimum fare: ', value: '₱20'),
          _bulletText(
            label: 'Student discount: ',
            value: '20% OFF',
            valueColor: Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}