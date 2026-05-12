import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  AppEnvironment._();

  static bool _isLoaded = false;

  static Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // The app also supports --dart-define and Android manifest placeholders.
    }

    _isLoaded = true;
  }

  static String get googleServicesApiKey {
    const fromDartDefine = String.fromEnvironment('GOOGLE_SERVICES_API_KEY');
    if (fromDartDefine.trim().isNotEmpty) {
      return fromDartDefine.trim();
    }

    try {
      return (dotenv.env['GOOGLE_SERVICES_API_KEY'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static bool get hasGoogleServicesApiKey => googleServicesApiKey.isNotEmpty;
}
