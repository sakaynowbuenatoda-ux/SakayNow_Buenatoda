import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

class AppEnvironment {
  AppEnvironment._();

  static const MethodChannel _platformChannel = MethodChannel(
    'sakaynow_buenatoda/environment',
  );

  static bool _isLoaded = false;
  static String _platformGoogleServicesApiKey = '';

  static Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // The app also supports --dart-define and Android manifest placeholders.
    }

    _platformGoogleServicesApiKey = await _readPlatformGoogleServicesApiKey();
    _isLoaded = true;
  }

  static String get googleServicesApiKey {
    const fromDartDefine = String.fromEnvironment('GOOGLE_SERVICES_API_KEY');
    final dartDefineValue = _cleanConfiguredValue(fromDartDefine);
    if (dartDefineValue.isNotEmpty) {
      return dartDefineValue;
    }

    try {
      final dotenvValue = _cleanConfiguredValue(
        dotenv.env['GOOGLE_SERVICES_API_KEY'] ?? '',
      );
      if (dotenvValue.isNotEmpty) {
        return dotenvValue;
      }
    } catch (_) {
      // The dotenv package throws if no .env asset was loaded.
    }

    return _platformGoogleServicesApiKey;
  }

  static bool get hasGoogleServicesApiKey => googleServicesApiKey.isNotEmpty;

  static Future<String> _readPlatformGoogleServicesApiKey() async {
    try {
      final value = await _platformChannel.invokeMethod<String>(
        'googleServicesApiKey',
      );
      return _cleanConfiguredValue(value ?? '');
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  static String _cleanConfiguredValue(String value) {
    final trimmed = value.trim().replaceAll('"', '').replaceAll("'", '');
    if (trimmed.isEmpty || trimmed.contains(r'$(')) {
      return '';
    }

    return trimmed;
  }
}
