import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fallback if env file missing in release
    }
  }

  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static String get appName => dotenv.env['APP_NAME'] ?? 'FitFuel';
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:5001/fitfuel-app/us-central1';
  static bool get isDevelopment => environment == 'development';
}
