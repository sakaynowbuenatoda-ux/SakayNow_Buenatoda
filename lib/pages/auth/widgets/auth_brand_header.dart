import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_assets.dart';
import '../auth_ui.dart';

class AuthBrandHeader extends StatelessWidget {
  final bool centered;

  const AuthBrandHeader({super.key, this.centered = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AuthUi.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'SakayNow BuenaToda',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AuthUi.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              Text(
                'Smart tricycle dispatch',
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
      ],
    );
  }
}
