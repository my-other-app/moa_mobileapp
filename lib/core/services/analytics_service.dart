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
  // USER PROPERTIES
  // ============================================================

  /// Set user ID for analytics and crash reports
  Future<void> setUserId(String? userId) async {
    await _sdk(() => _analytics.setUserId(id: userId));
    if (userId != null && _crashReportsOn) {
      await _crashlytics.setUserIdentifier(userId);
    }
  }

  /// Set custom user property
  Future<void> setUserProperty(String name, String? value) async {
    await _sdk(() => _analytics.setUserProperty(name: name, value: value));
  }

  // ============================================================
  // SCREEN TRACKING
  // ============================================================

  /// Log screen view
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    await _sdk(() => _analytics.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? screenName,
        ));
    debugPrint('Analytics: Screen view - $screenName');
  }

  // ============================================================
  // AUTH EVENTS
  // ============================================================

  /// Log login attempt started
  Future<void> logLoginStarted(String method) async {
    await _logEvent('login_started', {'method': method});
  }

  /// Log successful login
  Future<void> logLoginSuccess(String method, {String? userId}) async {
    await _sdk(() => _analytics.logLogin(loginMethod: method));
    await _logEvent('login_success', {
      'method': method,
      if (userId != null) 'user_id': userId,
    });
  }

  /// Log failed login
  Future<void> logLoginFailed(String method, String error) async {
    await _logEvent('login_failed', {
      'method': method,
      'error': _truncate(error, 100),
    });
    await logError('Login failed',
        error: error, parameters: {'method': method});
  }

  /// Log logout
  Future<void> logLogout() async {
    await _logEvent('logout', {});
  }

  /// Log signup/registration
  Future<void> logSignUp(String method) async {
    await _sdk(() => _analytics.logSignUp(signUpMethod: method));
  }

  // ============================================================
  // ONBOARDING EVENTS
  // ============================================================

  /// Log onboarding started
  Future<void> logOnboardingStarted() async {
    await _logEvent('onboarding_started', {});
  }

  /// Log profile creation
  Future<void> logProfileCreated(
      {bool hasOrg = false, bool hasWhatsapp = false}) async {
    await _logEvent('profile_created', {
      'has_organization': hasOrg,
      'has_whatsapp': hasWhatsapp,
    });
  }

  /// Log onboarding completed
  Future<void> logOnboardingCompleted() async {
    await _logEvent('onboarding_completed', {});
  }

  // ============================================================
  // EVENT (LISTING) EVENTS
  // ============================================================

  /// Log event view
  Future<void> logEventViewed(int eventId, String eventName) async {
    await _sdk(() => _analytics.logViewItem(items: [
          AnalyticsEventItem(itemId: eventId.toString(), itemName: eventName),
        ]));
    await _logEvent('event_viewed', {
      'event_id': eventId,
      'event_name': _truncate(eventName, 50),
    });
  }

  /// Log event registration
  Future<void> logEventRegistered(int eventId, String eventName) async {
    await _logEvent('event_registered', {
      'event_id': eventId,
      'event_name': _truncate(eventName, 50),
    });
  }

  /// Log event share
  Future<void> logEventShared(int eventId, String eventName) async {
    await _sdk(() => _analytics.logShare(
          contentType: 'event',
          itemId: eventId.toString(),
          method: 'share',
        ));
    await _logEvent('event_shared', {
      'event_id': eventId,
      'event_name': _truncate(eventName, 50),
    });
  }

  /// Log event added to calendar
  Future<void> logEventAddedToCalendar(int eventId, String eventName) async {
    await _logEvent('event_added_to_calendar', {
      'event_id': eventId,
      'event_name': _truncate(eventName, 50),
    });
  }

  /// Log event search
  Future<void> logEventSearch(String query, int resultsCount) async {
    await _sdk(() => _analytics.logSearch(searchTerm: query));
    await _logEvent('event_search', {
      'query': _truncate(query, 50),
      'results_count': resultsCount,
    });
  }

  // ============================================================
  // CLUB EVENTS
  // ============================================================

  /// Log club view
  Future<void> logClubViewed(int clubId, String clubName) async {
    await _logEvent('club_viewed', {
      'club_id': clubId,
      'club_name': _truncate(clubName, 50),
    });
  }

  /// Log club follow
  Future<void> logClubFollowed(int clubId, String clubName) async {
    await _logEvent('club_followed', {
      'club_id': clubId,
      'club_name': _truncate(clubName, 50),
    });
  }

  /// Log club unfollow
  Future<void> logClubUnfollowed(int clubId, String clubName) async {
    await _logEvent('club_unfollowed', {
      'club_id': clubId,
      'club_name': _truncate(clubName, 50),
    });
  }

  // ============================================================
  // TICKET & CERTIFICATE EVENTS
  // ============================================================

  /// Log ticket viewed
  Future<void> logTicketViewed(int eventId) async {
    await _logEvent('ticket_viewed', {'event_id': eventId});
  }

  /// Log ticket downloaded
  Future<void> logTicketDownloaded(int eventId) async {
    await _logEvent('ticket_downloaded', {'event_id': eventId});
  }

  /// Log wallet pass added
  Future<void> logWalletPassAdded(int eventId, {bool success = true}) async {
    await _logEvent('wallet_pass_added', {
      'event_id': eventId,
      'success': success,
    });
  }

  /// Log certificate viewed
  Future<void> logCertificateViewed(int eventId) async {
    await _logEvent('certificate_viewed', {'event_id': eventId});
  }

  /// Log certificate downloaded
  Future<void> logCertificateDownloaded(int eventId) async {
    await _logEvent('certificate_downloaded', {'event_id': eventId});
  }

  // ============================================================
  // NOTIFICATION EVENTS
  // ============================================================

  /// Log notification received
  Future<void> logNotificationReceived(String type) async {
    await _logEvent('notification_received', {'type': type});
  }

  /// Log notification opened
  Future<void> logNotificationOpened(String type) async {
    await _logEvent('notification_opened', {'type': type});
  }

  // ============================================================
  // NAVIGATION EVENTS
  // ============================================================

  /// Log bottom tab change
  Future<void> logTabChanged(String tabName) async {
    await _logEvent('tab_changed', {'tab_name': tabName});
  }

  /// Log search performed
  Future<void> logSearchPerformed(String query, int resultsCount) async {
    await _sdk(() => _analytics.logSearch(searchTerm: query));
    await _logEvent('search_performed', {
      'query': _truncate(query, 50),
      'results_count': resultsCount,
    });
  }

  // ============================================================
  // ERROR LOGGING
  // ============================================================

  /// Log non-fatal error
  Future<void> logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) async {
    // Log to Crashlytics
    if (_crashReportsOn) {
      await _crashlytics.log(message);
    }
    if (error != null && _crashReportsOn) {
      await _crashlytics.recordError(
        error is Exception ? error : Exception(error.toString()),
        stackTrace,
        reason: message,
        fatal: false,
      );
    }

    // Log to Analytics
    await _logEvent('app_error', {
      'message': _truncate(message, 100),
      if (error != null) 'error': _truncate(error.toString(), 100),
      ...?parameters,
    });

    debugPrint('Analytics: Error logged - $message');
  }

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

  /// Force a test crash (for testing Crashlytics)
  void forceCrash() {
    _crashlytics.crash();
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  /// One direct call to the Analytics SDK, made only while analytics is
  /// collected, and never allowed to throw into the screen that made it.
  Future<void> _sdk(Future<void> Function() call) async {
    if (!_analyticsOn) return;
    try {
      await call();
    } catch (e) {
      debugPrint('Analytics: call failed: $e');
    }
  }

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
