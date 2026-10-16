import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/config/env/environment.dart';

/// Application configuration class that holds all app-wide settings.
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  /// The public website: event pages (/events/{slug}), tickets, certificates
  /// and the live room. Older events.myotherapp.in links redirect here.
  static const publicSiteUrl = 'https://myotherapp.in';

  /// Current application environment
  Environment environment = Environment.development;

  /// API base URL from environment
  String get apiBaseUrl => Env.apiBaseUrl;

  /// Google OAuth Client ID
  String get googleClientId => Env.googleClientId;

  /// Whether analytics is enabled
  bool get isAnalyticsEnabled => Env.enableAnalytics.toLowerCase() == 'true';

  /// Initialize app configuration
  void initialize({Environment environment = Environment.development}) {
    this.environment = environment;
  }
}
