import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { light, dark }

enum AppLanguagePreference { english, filipino }

enum AppFontSizePreference { small, medium, large }

enum AppMapTypePreference { normal, satellite }

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController._();

  static final AppPreferencesController instance = AppPreferencesController._();

  static const String _themeKey = 'app_theme_preference';
  static const String _languageKey = 'app_language_preference';
  static const String _fontSizeKey = 'app_font_size_preference';
  static const String _mapTypeKey = 'app_map_type_preference';

  AppThemePreference _themePreference = AppThemePreference.light;
  AppLanguagePreference _languagePreference = AppLanguagePreference.english;
  AppFontSizePreference _fontSizePreference = AppFontSizePreference.medium;
  AppMapTypePreference _mapTypePreference = AppMapTypePreference.normal;

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get isDarkMode => _themePreference == AppThemePreference.dark;

  AppThemePreference get themePreference => _themePreference;
  AppLanguagePreference get languagePreference => _languagePreference;
  AppFontSizePreference get fontSizePreference => _fontSizePreference;
  AppMapTypePreference get mapTypePreference => _mapTypePreference;

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  MapType get googleMapType {
    switch (_mapTypePreference) {
      case AppMapTypePreference.normal:
        return MapType.normal;
      case AppMapTypePreference.satellite:
        return MapType.satellite;
    }
  }

  double get textScaleFactor {
    switch (_fontSizePreference) {
      case AppFontSizePreference.small:
        return 0.92;
      case AppFontSizePreference.medium:
        return 1.0;
      case AppFontSizePreference.large:
        return 1.14;
    }
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    _themePreference = _themeFromString(prefs.getString(_themeKey));
    _languagePreference = _languageFromString(prefs.getString(_languageKey));
    _fontSizePreference = _fontSizeFromString(prefs.getString(_fontSizeKey));
    _mapTypePreference = _mapTypeFromString(prefs.getString(_mapTypeKey));
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    if (_themePreference == value) {
      return;
    }

    _themePreference = value;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
  }

  Future<void> clearThemePreference() async {
    final shouldNotify = _themePreference != AppThemePreference.light;
    _themePreference = AppThemePreference.light;

    if (shouldNotify) {
      notifyListeners();
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
  }

  Future<void> setLanguagePreference(AppLanguagePreference value) async {
    if (_languagePreference == value) {
      return;
    }

    _languagePreference = value;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value.name);
  }

  Future<void> setFontSizePreference(AppFontSizePreference value) async {
    if (_fontSizePreference == value) {
      return;
    }

    _fontSizePreference = value;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, value.name);
  }

  Future<void> setMapTypePreference(AppMapTypePreference value) async {
    if (_mapTypePreference == value) {
      return;
    }

    _mapTypePreference = value;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapTypeKey, value.name);
  }

  AppThemePreference _themeFromString(String? value) {
    return AppThemePreference.values
        .where((entry) => entry.name == value)
        .fold(AppThemePreference.light, (_, entry) => entry);
  }

  AppLanguagePreference _languageFromString(String? value) {
    return AppLanguagePreference.values
        .where((entry) => entry.name == value)
        .fold(AppLanguagePreference.english, (_, entry) => entry);
  }

  AppFontSizePreference _fontSizeFromString(String? value) {
    return AppFontSizePreference.values
        .where((entry) => entry.name == value)
        .fold(AppFontSizePreference.medium, (_, entry) => entry);
  }

  AppMapTypePreference _mapTypeFromString(String? value) {
    return AppMapTypePreference.values
        .where((entry) => entry.name == value)
        .fold(AppMapTypePreference.normal, (_, entry) => entry);
  }
}
