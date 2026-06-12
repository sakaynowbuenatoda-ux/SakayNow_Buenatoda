import 'package:flutter/material.dart';

import 'core/preferences/app_preferences_controller.dart';
import 'core/session/privacy_security_session_guard.dart';
import 'pages/auth/auth_gate.dart';
import 'services/notification_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppPreferencesController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'SakayNow',
          theme: _buildTheme(brightness: Brightness.light),
          darkTheme: _buildTheme(brightness: Brightness.dark),
          themeMode: controller.themeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(controller.textScaleFactor),
              ),
              child: PrivacySecuritySessionGuard(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }

  ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final palette = _ThemePalette.fromBrightness(brightness);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          secondary: palette.secondary,
          tertiary: palette.accentBlue,
          surface: palette.surface,
          onSurface: palette.title,
          outline: palette.border,
        );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.title,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.title,
          fontSize: 20,
          fontWeight: FontWeight.w400,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.mutedSurface,
        hintStyle: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: palette.hint,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: palette.hint,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: palette.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: palette.accentBlue,
        suffixIconColor: palette.accentBlue,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.title : palette.dark,
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: isDark ? palette.dark : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? palette.primary : palette.dark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: palette.border),
          foregroundColor: palette.title,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: palette.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            fontSize: 11,
            height: 1.4,
            color: selected ? palette.primary : palette.body,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? palette.primary : palette.body,
            size: selected ? 24 : 22,
          );
        }),
      ),
      useMaterial3: true,
    );
  }
}

class _ThemePalette {
  final Color background;
  final Color surface;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color accentBlue;
  final Color title;
  final Color body;
  final Color mutedSurface;
  final Color hint;
  final Color dark;

  const _ThemePalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.accentBlue,
    required this.title,
    required this.body,
    required this.mutedSurface,
    required this.hint,
    required this.dark,
  });

  factory _ThemePalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _ThemePalette(
        background: Color(0xFF09090B),
        surface: Color(0xFF111318),
        border: Color(0xFF262A33),
        primary: Color(0xFF60A5FA),
        onPrimary: Colors.white,
        secondary: Color(0xFF4ADE80),
        accentBlue: Color(0xFF60A5FA),
        title: Color(0xFFF9FAFB),
        body: Color(0xFFB6BBC6),
        mutedSurface: Color(0xFF1A1D24),
        hint: Color(0xFF93C5FD),
        dark: Color(0xFF030213),
      );
    }

    return const _ThemePalette(
      background: Color(0xFFFCFCFD),
      surface: Colors.white,
      border: Color(0xFFE7E9EE),
      primary: Color(0xFF030213),
      onPrimary: Colors.white,
      secondary: Color(0xFF16A34A),
      accentBlue: Color(0xFF2563FF),
      title: Color(0xFF0B0D18),
      body: Color(0xFF667085),
      mutedSurface: Color(0xFFF3F4F6),
      hint: Color(0xFF2563FF),
      dark: Color(0xFF030213),
    );
  }
}
