import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// Crash reports: what is sent, when, and what is taken out first.
//
// Every report carries the app's version and build number already: the
// Crashlytics SDK reads them from the app itself (versionName/versionCode on
// Android, CFBundleShortVersionString/CFBundleVersion on iOS, both set from
// pubspec's `version`). Nothing that identifies the person is attached: no
// user id (the App Store privacy answers say crash data is not linked to
// them), no custom keys, and every piece of text is passed through
// [redactForCrashReport] on its way out.

/// What crash reports go to. The real one is Crashlytics
/// ([CrashlyticsSink]); tests hand in their own.
abstract class CrashSink {
  Future<void> recordError(
    String exception,
    StackTrace? stack, {
    String? reason,
    List<String> information = const [],
    required bool fatal,
  });

  Future<void> log(String message);
}

/// Crash reports to Firebase Crashlytics.
class CrashlyticsSink implements CrashSink {
  CrashlyticsSink(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    String exception,
    StackTrace? stack, {
    String? reason,
    List<String> information = const [],
    required bool fatal,
  }) =>
      _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        // Printed by the caller already, unredacted, in a debug build only.
        printDetails: false,
        fatal: fatal,
      );

  @override
  Future<void> log(String message) => _crashlytics.log(message);
}

/// Sends the app's crashes and errors to a [CrashSink], when [enabled]
/// says so, with emails, phone numbers and tokens taken out.
///
/// [install] makes it the handler for:
/// - errors the framework catches (`FlutterError.onError`): building,
///   layout, painting, gestures, image loads;
/// - errors nothing caught, outside any zone handler
///   (`PlatformDispatcher.onError`).
/// `main` sends the errors its `runZonedGuarded` zone catches to
/// [recordUncaught].
class CrashReporter {
  CrashReporter({required this.sink, required this.enabled});

  final CrashSink sink;

  /// Whether reports may be sent now: never in a debug build, never before
  /// the saved choice is known, and otherwise as the person chose in
  /// Settings ("Crash Reports"). Asked at every report, so the switch takes
  /// effect at once.
  final bool Function() enabled;

  /// Handle every framework and uncaught error from now on.
  void install() {
    FlutterError.onError = handleFlutterError;
    PlatformDispatcher.instance.onError = handlePlatformError;
  }

  /// `FlutterError.onError`. An image that failed to load is reported as
  /// non-fatal: a bad poster URL on a slow network leaves a placeholder,
  /// not a crashed app, and used to fill the crash-free figures.
  void handleFlutterError(FlutterErrorDetails details) {
    // What the framework does by default. In a debug build that is the
    // whole error in the console; in a release build, one line.
    FlutterError.presentError(details);
    if (!_on) return;
    final context =
        details.context?.toStringDeep(minLevel: DiagnosticLevel.info).trim();
    final information = details.informationCollector?.call() ?? const [];
    _send(
      sink.recordError(
        redactForCrashReport(details.exceptionAsString()),
        details.stack,
        reason: context == null ? null : redactForCrashReport(context),
        information: [
          for (final node in information) redactForCrashReport('$node'),
        ],
        fatal: !isNonFatalFlutterError(details),
      ),
    );
  }

  /// `PlatformDispatcher.onError`: an error nothing caught. Always handled
  /// here, so the engine does not print it a second time.
  bool handlePlatformError(Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('Uncaught error: $error\n$stack');
    recordUncaught(error, stack);
    return true;
  }

  /// An error nothing caught. Fatal, unless it is a failed image or network
  /// fetch that nothing awaited -- those leave the app running.
  void recordUncaught(Object error, StackTrace stack) {
    if (!_on) return;
    _send(sink.recordError(
      redactForCrashReport('$error'),
      stack,
      fatal: !isNonFatalError(error),
    ));
  }

  /// An error the app caught and carried on from, worth seeing anyway.
  void recordNonFatal(Object error, StackTrace? stack, {String? reason}) {
    if (!_on) return;
    _send(sink.recordError(
      redactForCrashReport('$error'),
      stack,
      reason: reason == null ? null : redactForCrashReport(reason),
      fatal: false,
    ));
  }

  /// A line for the log the next report carries.
  void log(String message) {
    if (!_on) return;
    _send(sink.log(redactForCrashReport(message)));
  }

  bool get _on {
    try {
      return enabled();
    } catch (_) {
      return false;
    }
  }

  /// Reporting must never become the next error: a sink that fails is
  /// noted in the console and otherwise ignored.
  void _send(Future<void> report) {
    report.catchError((Object e) {
      debugPrint('CrashReporter: could not send a report: $e');
    });
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

// ---------------------------------------------------------------------------
// Redaction
// ---------------------------------------------------------------------------

/// Names whose value is a secret or identifies someone, wherever they
/// appear as `name=value` (a query string) or `name: value` (a map, JSON).
const _sensitiveNames = [
  'access_token',
  'accesstoken',
  'refresh_token',
  'refreshtoken',
  'id_token',
  'idtoken',
  'fcm_token',
  'fcmtoken',
  'push_token',
  'device_token',
  'token',
  'password',
  'new_password',
  'old_password',
  'passcode',
  'otp',
  'secret',
  'client_secret',
  'api_key',
  'apikey',
  'authorization',
  'signature',
  'razorpay_signature',
  'email',
  'phone',
  'phone_number',
  'mobile',
  'whatsapp',
  'whatsapp_number',
];

final _sensitivePair = RegExp(
  '\\b(${_sensitiveNames.join('|')})(["\']?\\s*[:=]\\s*["\']?)'
  '[^\\s"\'&,;)}\\]]+',
  caseSensitive: false,
);

/// A JSON Web Token: three base64url parts, the first `{"` encoded.
final _jwt = RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*');

final _authHeader = RegExp(r'\b(Bearer|Basic|Token)\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false);

/// An email address, with its `@` plain or URL-encoded.
final _email = RegExp(
  r'[A-Za-z0-9._%+-]+(?:@|%40)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}',
);

/// A number written with a country code: `+91 98765 43210`, `+1 (415) 555-0100`.
final _internationalPhone = RegExp(r'\+\d[\d\s().-]{7,16}\d');

/// An Indian mobile number on its own: ten digits from 6-9, possibly split
/// 5+5, possibly after 0 or 91. Not part of a longer number, a word or a
/// decimal, so ids, timestamps, hashes and line numbers are left alone.
final _indianMobile = RegExp(
  r'(?<![\w.+])(?:0|91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}(?![\w.])',
);

/// [text] with emails, phone numbers and tokens replaced by placeholders:
/// what may go into a crash report or an analytics event.
String redactForCrashReport(String text) {
  return text
      // The header first: `authorization: Bearer x` must lose x, not only
      // the word after the colon.
      .replaceAllMapped(_authHeader, (m) => '${m[1]} <token>')
      .replaceAll(_jwt, '<token>')
      .replaceAllMapped(_sensitivePair, (m) => '${m[1]}${m[2]}<redacted>')
      .replaceAll(_email, '<email>')
      .replaceAll(_internationalPhone, '<phone>')
      .replaceAll(_indianMobile, '<phone>');
}
