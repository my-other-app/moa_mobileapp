import 'package:envied/envied.dart';

part 'env.g.dart';

/// Environment configuration using envied for secure access to environment variables.
///
/// Run `dart run build_runner build --delete-conflicting-outputs` to generate env.g.dart
@Envied(path: '.env', obfuscate: true)
abstract class Env {
  /// API base URL for network requests
  @EnviedField(varName: 'API_BASE_URL')
  static String get apiBaseUrl => _Env.apiBaseUrl;

  /// Google OAuth Client ID
  @EnviedField(varName: 'GOOGLE_CLIENT_ID')
  static String get googleClientId => _Env.googleClientId;

  /// Enable analytics tracking
  @EnviedField(varName: 'ENABLE_ANALYTICS', defaultValue: 'false')
  static String get enableAnalytics => _Env.enableAnalytics;
}
