import 'dart:io';

import 'package:finnet/core/services/analytics_service.dart' show apiPathOf;
import 'package:finnet/core/services/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A report as the sink received it.
class _Report {
  _Report(
      this.exception, this.stack, this.reason, this.information, this.fatal);
  final String exception;
  final StackTrace? stack;
  final String? reason;
  final List<String> information;
  final bool fatal;
}

class _Sink implements CrashSink {
  final reports = <_Report>[];
  final logs = <String>[];
  bool fail = false;

  @override
  Future<void> recordError(String exception, StackTrace? stack,
      {String? reason,
      List<String> information = const [],
      required bool fatal}) async {
    if (fail) throw StateError('no Crashlytics');
    reports.add(_Report(exception, stack, reason, information, fatal));
  }

  @override
  Future<void> log(String message) async {
    if (fail) throw StateError('no Crashlytics');
    logs.add(message);
  }
}

void main() {
  group('redactForCrashReport takes out', () {
    test('email addresses, plain or URL-encoded', () {
      expect(redactForCrashReport('No account for deepu.k+1@example.co.in'),
          'No account for <email>');
      expect(redactForCrashReport('/auth/check?email=a.b%40mail.com'),
          '/auth/check?email=<redacted>');
      expect(redactForCrashReport('GET /users/a.b%40mail.com/profile'),
          'GET /users/<email>/profile');
      // How a Text widget shows up in a layout error.
      expect(
        redactForCrashReport('Text("someone@college.edu", overflow: clip)'),
        'Text("<email>", overflow: clip)',
      );
    });

    test('phone numbers, Indian and international', () {
      for (final phone in [
        '9876543210',
        '98765 43210',
        '98765-43210',
        '+91 98765 43210',
        '+919876543210',
        '09876543210',
        '+1 (415) 555-0100',
      ]) {
        expect(redactForCrashReport('call $phone now'), 'call <phone> now',
            reason: phone);
      }
    });

    test('tokens, keys and passwords', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJl';
      expect(
          redactForCrashReport('token $jwt expired'), 'token <token> expired');
      expect(redactForCrashReport('Authorization: Bearer abc.def-123'),
          'Authorization: <redacted> <token>');
      expect(
        redactForCrashReport(
            '{"access_token": "at-1", "refresh_token": "rt-2", "name": "x"}'),
        '{"access_token": "<redacted>", "refresh_token": "<redacted>", '
        '"name": "x"}',
      );
      expect(redactForCrashReport('/x?token=s3cr3t&page=2'),
          '/x?token=<redacted>&page=2');
      expect(redactForCrashReport('{password: hunter2, otp: 123456}'),
          '{password: <redacted>, otp: <redacted>}');
      expect(redactForCrashReport('{phone: 12345, whatsapp: 67890}'),
          '{phone: <redacted>, whatsapp: <redacted>}');
    });
  });

  group('redactForCrashReport leaves alone', () {
    test('what a report needs to be read', () {
      for (final text in [
        'ApiException: Not found (notFound, code: 404)',
        '#0      main (package:finnet/main.dart:123:45)',
        'RenderFlex overflowed by 12.5 pixels on the right.',
        'event 1729771234567 at 2026-10-24 12:00:00',
        'commit 98a76543210bcdef',
        'version 1.1.0+3, build 3',
        'id 6789012345678',
        'Bad state: No element',
      ]) {
        expect(redactForCrashReport(text), text);
      }
    });
  });

  group('CrashReporter', () {
    late _Sink sink;
    late bool on;
    late CrashReporter reporter;
    late void Function(FlutterErrorDetails) presentError;
    final presented = <FlutterErrorDetails>[];

    setUp(() {
      sink = _Sink();
      on = true;
      reporter = CrashReporter(sink: sink, enabled: () => on);
      presented.clear();
      presentError = FlutterError.presentError;
      FlutterError.presentError = presented.add;
    });

    tearDown(() => FlutterError.presentError = presentError);

    test('a framework error: shown, then reported fatal and redacted', () {
      final details = FlutterErrorDetails(
        exception: FlutterError('A RenderFlex overflowed: me@example.com'),
        stack: StackTrace.current,
        library: 'rendering library',
        context: ErrorDescription('during layout of 9876543210'),
        informationCollector: () => [
          ErrorDescription('The widget was Text("me@example.com")'),
        ],
      );

      reporter.handleFlutterError(details);

      expect(presented, [details]);
      final report = sink.reports.single;
      expect(report.fatal, isTrue);
      expect(report.exception, contains('<email>'));
      expect(report.exception, isNot(contains('me@example.com')));
      expect(report.reason, 'during layout of <phone>');
      expect(report.information, ['The widget was Text("<email>")']);
      expect(report.stack, details.stack);
    });

    test('an image that failed to load is reported, not as a crash', () {
      reporter.handleFlutterError(FlutterErrorDetails(
        exception: const HttpException('Invalid statusCode: 404'),
        library: 'image resource service',
      ));

      expect(sink.reports.single.fatal, isFalse);
    });

    test('an uncaught error: fatal unless it is a failed fetch', () {
      reporter.recordUncaught(
          StateError('no user deepu@x.io'), StackTrace.current);
      reporter.recordUncaught(
          const SocketException('Failed host lookup'), StackTrace.current);

      expect(sink.reports.map((r) => r.fatal), [true, false]);
      expect(sink.reports.first.exception, 'Bad state: no user <email>');
    });

    test('PlatformDispatcher errors are handled and reported', () {
      expect(reporter.handlePlatformError(StateError('x'), StackTrace.current),
          isTrue);
      expect(sink.reports.single.fatal, isTrue);
    });

    test('a caught error is non-fatal, with its reason redacted', () {
      reporter.recordNonFatal(StateError('x'), null,
          reason: 'while saving +91 98765 43210');

      expect(sink.reports.single.fatal, isFalse);
      expect(sink.reports.single.reason, 'while saving <phone>');
    });

    test('log lines are redacted', () {
      reporter.log('API Error: /users/me@example.com - 404');

      expect(sink.logs, ['API Error: /users/<email> - 404']);
    });

    test('nothing is sent while the switch is off, and at once after', () {
      on = false;
      reporter.handleFlutterError(
          FlutterErrorDetails(exception: FlutterError('x')));
      reporter.recordUncaught(StateError('x'), StackTrace.current);
      reporter.recordNonFatal(StateError('x'), null);
      reporter.log('x');

      expect(sink.reports, isEmpty);
      expect(sink.logs, isEmpty);
      // Still shown in the console.
      expect(presented, hasLength(1));

      on = true;
      reporter.recordUncaught(StateError('y'), StackTrace.current);
      expect(sink.reports, hasLength(1));
    });

    test('a switch that cannot be read counts as off', () {
      final throwing = CrashReporter(
          sink: sink, enabled: () => throw StateError('no Firebase'));
      throwing.recordUncaught(StateError('x'), StackTrace.current);

      expect(sink.reports, isEmpty);
    });

    test('a sink that fails does not become the next error', () async {
      sink.fail = true;
      reporter.recordUncaught(StateError('x'), StackTrace.current);
      reporter.log('x');
      await pumpEventQueue();
    });

    test('install handles framework and uncaught errors', () {
      final flutterOnError = FlutterError.onError;
      final platformOnError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = flutterOnError;
        PlatformDispatcher.instance.onError = platformOnError;
      });

      reporter.install();
      FlutterError.onError!(FlutterErrorDetails(exception: FlutterError('a')));
      final handled = PlatformDispatcher.instance.onError!(
          StateError('b'), StackTrace.empty);
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;

      expect(handled, isTrue);
      expect(sink.reports, hasLength(2));
    });
  });

  group('apiPathOf', () {
    test('drops the query string and fragment', () {
      expect(apiPathOf('/events/list?search=priya'), '/events/list');
      expect(apiPathOf('/a#b'), '/a');
      expect(apiPathOf('/clubs/info/4'), '/clubs/info/4');
    });

    test('keeps only the path of a full URL', () {
      expect(apiPathOf('https://api.myotherapp.in/api/v1/user/me?x=1'),
          '/api/v1/user/me');
    });
  });

  group('secrets in addresses', () {
    test('a ticket-shaped path loses its code, for Crashlytics and Analytics',
        () {
      expect(apiPathOf('/events/tickets/MOA-7K3QF-X9PWM/image'),
          '/events/tickets/:code/image');
      expect(apiPathOf('/events/tickets/MOA-3F2A9C-K7QXD/pdf?download=1'),
          '/events/tickets/:code/pdf');
      expect(apiPathOf('/events/tickets/MOA-7K3QF-X9PWM/wallet.pkpass'),
          '/events/tickets/:code/wallet.pkpass');
      expect(apiPathOf('/events/tickets/MOA-7K3QF-X9PWM'),
          '/events/tickets/:code');
    });

    test('offer and request tokens, certificates, answers and feedback links',
        () {
      for (final (path, shape) in [
        ('/waitlist/offers/tok_9f8e7d6c5b4a', '/waitlist/offers/:token'),
        (
          '/waitlist/offers/tok_9f8e7d6c5b4a/claim',
          '/waitlist/offers/:token/claim'
        ),
        (
          '/waitlist/offers/tok_9f8e7d6c5b4a/decline',
          '/waitlist/offers/:token/decline'
        ),
        ('/registration-requests/rq_abcdef123456', '/registration-requests/:token'),
        (
          '/events/certificates/MOA-7K3QF-X9PWM/image',
          '/events/certificates/:id/image'
        ),
        (
          '/events/7/answers/3f2a9c1e-0b4d-4e5f-8a6b-7c8d9e0f1a2b',
          '/events/7/answers/:ref'
        ),
        (
          '/events/7/feedback/3f2a9c1e-0b4d-4e5f-8a6b-7c8d9e0f1a2b',
          '/events/7/feedback/:ref'
        ),
        (
          '/events/7/gate/check-in/3f2a9c1e-0b4d-4e5f-8a6b-7c8d9e0f1a2b',
          '/events/7/gate/check-in/:id'
        ),
        (
          '/events/7/gate/merch/3f2a9c1e-0b4d-4e5f-8a6b-7c8d9e0f1a2b',
          '/events/7/gate/merch/:id'
        ),
        // Handles too (Feature 4), through the same address.
        ('/profiles/ananya.iyer', '/profiles/:handle'),
      ]) {
        expect(apiPathOf(path), shape, reason: path);
      }
    });

    test("the app's own links lose theirs as well", () {
      for (final (path, shape) in [
        ('/tickets/MOA-7K3QF-X9PWM', '/tickets/:code'),
        ('/claim/tok_9f8e7d6c5b4a', '/claim/:token'),
        ('/requests/rq_abcdef123456', '/requests/:token'),
        ('/answers/7/abcdef123456', '/answers/:ref'),
        ('/feedback/7/3f2a9c1e-0b4d', '/feedback/:ref'),
        ('/profile/certificates/MOA-7K3QF-X9PWM', '/profile/certificates/:id'),
      ]) {
        expect(redactForCrashReport(path), shape, reason: path);
      }
    });

    test('a ticket code written out anywhere is taken out', () {
      expect(redactForCrashReport('No ticket matches MOA-7K3QF-X9PWM.'),
          'No ticket matches <ticket>.');
      // Nothing secret is lost from what is not one.
      expect(redactForCrashReport('/events/7/gate/context'),
          '/events/7/gate/context');
      expect(redactForCrashReport('/events/hack-night-04/ticket-types'),
          '/events/hack-night-04/ticket-types');
    });

    test('the crash log line and the api_error event both get the shape',
        () {
      final sink = _Sink();
      final reporter = CrashReporter(sink: sink, enabled: () => true);
      reporter.log('API Error: /events/tickets/MOA-7K3QF-X9PWM/image - 404');

      expect(sink.logs, ['API Error: /events/tickets/:code/image - 404']);
    });
  });
}
