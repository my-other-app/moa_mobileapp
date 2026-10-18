import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Comprehensive analytics and crash reporting service.
///
/// This service provides:
/// - Screen view tracking
/// - User action events
/// - Error/crash logging
/// - User properties
class AnalyticsService {
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

  /// Initialize Crashlytics with Flutter error handling
  Future<void> initialize() async {
    // Enable crashlytics collection
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Pass all uncaught Flutter errors to Crashlytics. An image that failed
    // to load is reported through FlutterError too, and every one of them
    // used to be filed as a fatal crash: a bad poster URL on a slow network
    // filled the crash-free-users figure with sessions that never crashed.
    FlutterError.onError = (errorDetails) {
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
    _crashlytics.recordError(error, stack, fatal: !isNonFatalError(error));
  }

  // ============================================================
  // USER PROPERTIES
  // ============================================================

  /// Set user ID for analytics and crash reports
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
    if (userId != null) {
      await _crashlytics.setUserIdentifier(userId);
    }
  }

  /// Set custom user property
  Future<void> setUserProperty(String name, String? value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // ============================================================
  // SCREEN TRACKING
  // ============================================================

  /// Log screen view
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
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
    await _analytics.logLogin(loginMethod: method);
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
    await _analytics.logSignUp(signUpMethod: method);
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
    await _analytics.logViewItem(items: [
      AnalyticsEventItem(itemId: eventId.toString(), itemName: eventName),
    ]);
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
    await _analytics.logShare(
      contentType: 'event',
      itemId: eventId.toString(),
      method: 'share',
    );
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
    await _analytics.logSearch(searchTerm: query);
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
    await _analytics.logSearch(searchTerm: query);
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
    await _crashlytics.log(message);
    if (error != null) {
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
    await _crashlytics.log('API Error: $endpoint - $statusCode');
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

  /// Log custom event with parameters
  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
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
