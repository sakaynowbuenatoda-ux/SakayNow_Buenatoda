import 'package:flutter/material.dart';

import '../core/auth/registration_service.dart';

class RegistrationImagePreview extends StatelessWidget {
  final RegistrationImageSelection selection;
  final double height;
  final double borderRadius;

  const RegistrationImagePreview({
    super.key,
    required this.selection,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        selection.bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) {
          return Container(
            height: height,
            width: double.infinity,
            color: const Color(0xFFE5E7EB),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF6B7280),
              size: 32,
            ),
          );
        },
      ),
    );
  }
}
