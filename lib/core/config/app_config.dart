import 'package:finnet/core/config/env/env.dart';

/// Application configuration class that holds all app-wide settings.
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  /// The public website: event pages (/events/{slug}), tickets, certificates
  /// and the live room. Older events.myotherapp.in links redirect here.
  static const publicSiteUrl = 'https://myotherapp.in';

  /// Whether this build may collect usage analytics at all
  /// (`ENABLE_ANALYTICS`). True for store builds; false keeps a development
  /// build out of the production numbers. Within a build that allows it,
  /// the person's "Share usage analytics" switch decides
  /// (`AnalyticsService.applyChoices`). Crash reports do not depend on it.
  bool get isAnalyticsEnabled => Env.enableAnalytics.toLowerCase() == 'true';
}
