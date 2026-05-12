import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_environment.dart';
import 'core/preferences/app_preferences_controller.dart';
import 'firebase_options.dart';
import 'widgets/passenger_widgets/passenger_ui.dart';
import 'pages/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppEnvironment.load();
  await AppPreferencesController.instance.load();
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppPreferencesController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
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
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AuthGate(),
        );
      },
    );
  }

  ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: isDark ? Color(0xFFF9FAFB) : Color(0xFF030213),
          brightness: brightness,
        ).copyWith(
          primary: PassengerUi.primary,
          secondary: PassengerUi.secondary,
          tertiary: PassengerUi.accentBlue,
          surface: PassengerUi.surface,
          onSurface: PassengerUi.title,
          outline: PassengerUi.border,
        );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: PassengerUi.background,
      appBarTheme: AppBarTheme(
        backgroundColor: PassengerUi.surface,
        foregroundColor: PassengerUi.title,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: PassengerUi.cardTitle.copyWith(
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
        fillColor: PassengerUi.mutedSurface,
        hintStyle: PassengerUi.bodyText.copyWith(
          color: PassengerUi.hint,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: PassengerUi.bodyText.copyWith(
          color: PassengerUi.hint,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: PassengerUi.bodyText.copyWith(
          color: PassengerUi.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: PassengerUi.accentBlue,
        suffixIconColor: PassengerUi.accentBlue,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PassengerUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PassengerUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PassengerUi.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? Color(0xFFF9FAFB) : Color(0xFF030213),
        contentTextStyle: PassengerUi.bodyText.copyWith(
          color: isDark ? Color(0xFF030213) : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: PassengerUi.dark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: PassengerUi.border),
          foregroundColor: PassengerUi.title,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PassengerUi.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: PassengerUi.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return PassengerUi.bodyText.copyWith(
            fontSize: 11,
            color: selected ? PassengerUi.primary : PassengerUi.body,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? PassengerUi.primary : PassengerUi.body,
            size: selected ? 24 : 22,
          );
        }),
      ),
      useMaterial3: true,
    );
  }
}
