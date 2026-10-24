import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/core/services/crash_reporting.dart';
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

/// Firebase Analytics and Crashlytics, collecting only what the person
/// allows: screen views (through [observer]), failed API calls, and crash
/// reports ([crashReporter]).
class AnalyticsService implements CollectionControl {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Where crashes and errors are reported: Crashlytics, while
  /// [_crashReportsOn], with emails, phone numbers and tokens taken out.
  late final CrashReporter crashReporter = CrashReporter(
    sink: CrashlyticsSink(_crashlytics),
    enabled: () => _crashReportsOn,
  );

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

  /// Whether the saved choices have been applied. Until then nothing is
  /// reported: an error in the first moments of a start must not go out
  /// for someone who turned crash reports off.
  bool _choicesApplied = false;

  bool get _analyticsOn =>
      analyticsCollected(_choices, buildAllows: AppConfig().isAnalyticsEnabled);

  bool get _crashReportsOn =>
      _choicesApplied && crashReportsCollected(_choices, debug: kDebugMode);

  /// Initialize Crashlytics with Flutter error handling, and collect only
  /// what the person agreed to.
  ///
  /// Run at start-up (main.dart), before the first frame. Both SDKs also
  /// keep the last setting themselves, so after someone turns a switch off
  /// the next launch starts with it off even before this runs.
  Future<void> initialize({PrivacyChoicesStore? store}) async {
    await applySavedChoices(store ?? FilePrivacyChoicesStore(), this);

    // Framework errors (FlutterError.onError) and errors nothing caught
    // (PlatformDispatcher.onError) from here on; main's zone sends its own
    // to recordUncaughtError.
    crashReporter.install();

    debugPrint('AnalyticsService: Initialized');
  }

  /// Record an error nothing caught: the `runZonedGuarded` zone in main.
  void recordUncaughtError(Object error, StackTrace stack) =>
      crashReporter.recordUncaught(error, stack);

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
    _choicesApplied = true;
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

  /// A failed API call: a line in the next crash report's log, and an
  /// `api_error` event. The path only (no query string, which can carry a
  /// search or an address), and nothing that identifies the person.
  Future<void> logApiError(
    String endpoint,
    int? statusCode,
    String? errorMessage,
  ) async {
    final path = redactForCrashReport(apiPathOf(endpoint));
    crashReporter.log('API Error: $path - $statusCode');
    await _logEvent('api_error', {
      'endpoint': _truncate(path, 50),
      'status_code': statusCode ?? 0,
      'error': _truncate(redactForCrashReport(errorMessage ?? 'Unknown'), 100),
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

/// [endpoint] without its query string or fragment: `/events/list` for
/// `/events/list?search=x`, and the path of a full URL.
@visibleForTesting
String apiPathOf(String endpoint) {
  final cut = endpoint.indexOf(RegExp('[?#]'));
  final bare = cut < 0 ? endpoint : endpoint.substring(0, cut);
  final uri = Uri.tryParse(bare);
  return uri != null && uri.hasScheme ? uri.path : bare;
}
