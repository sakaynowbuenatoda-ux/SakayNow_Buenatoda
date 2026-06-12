import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySecurityPreferencesController extends ChangeNotifier {
  PrivacySecurityPreferencesController._();

  static final PrivacySecurityPreferencesController instance =
      PrivacySecurityPreferencesController._();

  static const String _autoLogoutEnabledKey =
      'privacy_security_auto_logout_enabled';
  static const String _autoLogoutMinutesKey =
      'privacy_security_auto_logout_minutes';
  static const String _appLockEnabledKey = 'privacy_security_app_lock_enabled';

  bool _autoLogoutEnabled = false;
  int _autoLogoutMinutes = 30;
  bool _appLockEnabled = false;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get autoLogoutEnabled => _autoLogoutEnabled;
  int get autoLogoutMinutes => _autoLogoutMinutes;
  bool get appLockEnabled => _appLockEnabled;

  Duration get autoLogoutDuration => Duration(minutes: _autoLogoutMinutes);

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    _autoLogoutEnabled = prefs.getBool(_autoLogoutEnabledKey) ?? false;
    _autoLogoutMinutes = _normalizeAutoLogoutMinutes(
      prefs.getInt(_autoLogoutMinutesKey),
    );
    _appLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setAutoLogoutEnabled(bool value) async {
    if (_autoLogoutEnabled == value) {
      return;
    }

    _autoLogoutEnabled = value;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLogoutEnabledKey, value);
  }

  Future<void> setAutoLogoutMinutes(int value) async {
    final normalizedValue = _normalizeAutoLogoutMinutes(value);
    if (_autoLogoutMinutes == normalizedValue) {
      return;
    }

    _autoLogoutMinutes = normalizedValue;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLogoutMinutesKey, normalizedValue);
  }

  Future<void> setAppLockEnabled(bool value) async {
    if (_appLockEnabled == value) {
      return;
    }

    _appLockEnabled = value;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledKey, value);
  }

  int _normalizeAutoLogoutMinutes(int? value) {
    return switch (value) {
      15 || 30 || 60 => value!,
      _ => 30,
    };
  }
}
