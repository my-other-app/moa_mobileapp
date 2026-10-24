import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/core/services/privacy_choices.dart';

export 'package:finnet/core/services/privacy_choices.dart';

/// What turns collection on and off: the app's [AnalyticsService]. A
/// provider so Settings can be tested without Firebase.
///
/// When Firebase failed to start, [AnalyticsService.instance] throws; the
/// switches then only save the choice, which the next start applies.
final collectionControlProvider = Provider<CollectionControl>((ref) {
  try {
    return AnalyticsService.instance;
  } catch (e) {
    debugPrint('AnalyticsService unavailable: $e');
    return const _SavedOnly();
  }
});

class _SavedOnly implements CollectionControl {
  const _SavedOnly();

  @override
  Future<void> applyChoices(PrivacyChoices choices) async {}
}

/// Whether usage analytics may be collected at all: this build's
/// `ENABLE_ANALYTICS` and the person's own choice, both.
///
/// `ENABLE_ANALYTICS` is the build's master switch for Analytics. Store
/// builds set it to true (docs/RELEASE_1.1.0.md); development builds leave it
/// false, so nobody's test taps end up in the production numbers. Within a
/// build that allows it, the person decides in Settings.
@visibleForTesting
bool analyticsCollected(PrivacyChoices choices, {required bool buildAllows}) =>
    buildAllows && choices.analytics;

/// Whether crash reports may be sent: never from a debug build (as before),
/// otherwise as the person chose.
@visibleForTesting
bool crashReportsCollected(PrivacyChoices choices, {required bool debug}) =>
    !debug && choices.crashReports;

/// Comprehensive analytics and crash reporting service.
///
/// This service provides:
/// - Screen view tracking
/// - User action events
/// - Error/crash logging
/// - User properties
class AnalyticsService implements CollectionControl {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// The person's choices as last applied. The defaults (both on) until
  /// [initialize] has read the saved ones.
  PrivacyChoices _choices = PrivacyChoices.defaults;
  PrivacyChoices get choices => _choices;

  bool get _analyticsOn =>
      analyticsCollected(_choices, buildAllows: AppConfig().isAnalyticsEnabled);

  bool get _crashReportsOn =>
      crashReportsCollected(_choices, debug: kDebugMode);

  /// Initialize Crashlytics with Flutter error handling, and collect only
  /// what the person agreed to.
  ///
  /// Run at start-up (main.dart), before the first frame. Both SDKs also
  /// keep the last setting themselves, so after someone turns a switch off
  /// the next launch starts with it off even before this runs.
  Future<void> initialize({PrivacyChoicesStore? store}) async {
    await applySavedChoices(store ?? FilePrivacyChoicesStore(), this);

    // Pass all uncaught Flutter errors to Crashlytics. An image that failed
    // to load is reported through FlutterError too, and every one of them
    // used to be filed as a fatal crash: a bad poster URL on a slow network
    // filled the crash-free-users figure with sessions that never crashed.
    FlutterError.onError = (errorDetails) {
      // Collection is off in debug builds, so without this a developer saw
      // nothing at all in the console for a build or layout error.
      if (kDebugMode) FlutterError.presentError(errorDetails);
      if (!_crashReportsOn) return;
      if (isNonFatalFlutterError(errorDetails)) {
        _crashlytics.recordFlutterError(errorDetails);
      } else {
        _crashlytics.recordFlutterFatalError(errorDetails);
      }
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      recordUncaughtError(error, stack);
      return true;
    };

    debugPrint('AnalyticsService: Initialized');
  }

  /// Record an error nothing caught. Fatal, unless it is a failed image or
  /// network fetch that nothing awaited -- those leave the app running.
  void recordUncaughtError(Object error, StackTrace stack) {
    if (!_crashReportsOn) return;
    _crashlytics.recordError(error, stack, fatal: !isNonFatalError(error));
  }

  // ============================================================
  // WHAT IS COLLECTED
  // ============================================================

  /// Collect what [choices] allows, from now on.
  ///
  /// Turning crash reports off also deletes any report kept on the phone
  /// and not yet sent; turning them back on deletes them too, so nothing
  /// from the time they were off goes out afterwards. Never throws: a
  /// Firebase that failed to start must not take Settings with it.
  @override
  Future<void> applyChoices(PrivacyChoices choices) async {
    _choices = choices;
    try {
      await _analytics.setAnalyticsCollectionEnabled(_analyticsOn);
    } catch (e) {
      debugPrint('AnalyticsService: could not set analytics collection: $e');
    }
    try {
      await _crashlytics.deleteUnsentReports();
      await _crashlytics.setCrashlyticsCollectionEnabled(_crashReportsOn);
    } catch (e) {
      debugPrint('AnalyticsService: could not set crash reporting: $e');
    }
  }

  // ============================================================
  // ERROR LOGGING
  // ============================================================

  /// Log API error
  Future<void> logApiError(
    String endpoint,
    int? statusCode,
    String? errorMessage,
  ) async {
    if (_crashReportsOn) {
      await _crashlytics.log('API Error: $endpoint - $statusCode');
    }
    await _logEvent('api_error', {
      'endpoint': _truncate(endpoint, 50),
      'status_code': statusCode ?? 0,
      'error': _truncate(errorMessage ?? 'Unknown', 100),
    });
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  /// Log custom event with parameters
  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    // The SDK drops events once collection is off; this keeps them from
    // being built and logged in the first place.
    if (!_analyticsOn) return;
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('Analytics: Event - $name $parameters');
    } catch (e) {
      debugPrint('Analytics: Failed to log event $name: $e');
    }
  }

  /// Truncate string to max length
  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}

/// Whether a [FlutterError] should be recorded as non-fatal.
///
/// Images report their load failures through [FlutterError] with the library
/// `image resource service` -- [NetworkImage] and `cached_network_image`
/// alike -- and a poster that fails to load leaves a placeholder, not a
/// crashed app.
@visibleForTesting
bool isNonFatalFlutterError(FlutterErrorDetails details) {
  return details.library == 'image resource service' ||
      isNonFatalError(details.exception);
}

/// Whether an uncaught error is a failed image or network fetch rather than
/// a crash.
@visibleForTesting
bool isNonFatalError(Object error) {
  return error is NetworkImageLoadException ||
      error is HttpException ||
      error is SocketException;
}
