import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_assets.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthUi.scope(
      context,
      Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: AuthUi.mapGradient),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + PassengerUi.pageBottomInset(context),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF0C2238).withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        AppAssets.logo,
                        fit: BoxFit.cover,
                      ),
                    ),

                    SizedBox(height: 24),

                    Text(
                      'SakayNow Buenatoda',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.luckiestGuy(
                        fontSize: 26,
                        color: AuthUi.primary,
                        letterSpacing: 0.3,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Fast, safe, and convenient commuting',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AuthUi.body,
                      ),
                    ),

                    SizedBox(height: 36),

                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3.2),
                    ),

                    SizedBox(height: 14),

                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AuthUi.title,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
