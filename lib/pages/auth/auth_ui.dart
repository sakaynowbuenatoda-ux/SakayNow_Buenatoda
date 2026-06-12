import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthUi {
  const AuthUi._();

  static const Color background = Color(0xFFF7F8FB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE7E9EE);
  static const Color primary = Color(0xFF030213);
  static const Color secondary = Color(0xFF16A34A);
  static const Color accentBlue = Color(0xFF2563FF);
  static const Color title = Color(0xFF0B0D18);
  static const Color body = Color(0xFF667085);
  static const Color mutedSurface = Color(0xFFF3F4F6);

  static LinearGradient get darkActionGradient => const LinearGradient(
    colors: <Color>[Color(0xFF020213), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get signalGradient => const LinearGradient(
    colors: <Color>[Color(0xFF020213), Color(0xFF202536)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get mapGradient => const LinearGradient(
    colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF7F8FB), Color(0xFFF3F4F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => <BoxShadow>[
    BoxShadow(
      color: Color(0xFF111827).withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static TextStyle get bodyText =>
      GoogleFonts.poppins(fontSize: 14, color: body, height: 1.4);

  static ThemeData theme(BuildContext context) {
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(),
      useMaterial3: true,
    );

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: title,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: title,
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: border,
      iconTheme: const IconThemeData(color: title),
      textTheme: base.textTheme.apply(bodyColor: title, displayColor: title),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mutedSurface,
        hintStyle: GoogleFonts.poppins(
          color: accentBlue,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.poppins(
          color: accentBlue,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: accentBlue,
        suffixIconColor: accentBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: mutedSurface,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: title,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  static Widget scope(BuildContext context, Widget child) {
    return Theme(data: theme(context), child: child);
  }
}
