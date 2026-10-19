import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/profile/data/datasources/certificate_remote_datasource.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_verification.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_detail_page.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_verify_page.dart';
import 'package:finnet/features/profile/presentation/profile_routes.dart';
import 'package:finnet/features/profile/presentation/utils/certificate_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

const _valid = {
  'valid': true,
  'reason': 'ok',
  'number': 'CERT-7K3QF-X9PWM',
  'attendee_name': 'Asha Menon',
  'event_name': 'Robo Wars 2026',
  'org_name': 'Robotics Club',
  'issued_at': '2026-10-12T18:30:00+05:30',
};

final _certificate = Certificate(
  ticketId: 'MOA-7K3QF-X9PWM',
  eventId: 7,
  eventName: 'Robo Wars 2026',
  clubName: 'Robotics Club',
  issuedOn: DateTime(2026, 10, 12),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The verify page (or [home]) in a router with the verify routes, signed
/// out as far as anything here knows.
Future<GoRouter> _pump(WidgetTester tester,
    {String location = '/verify/certificates',
    Widget? home,
    List<Override> overrides = const []}) async {
  final router = GoRouter(
    initialLocation: home == null ? location : '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => home ?? const SizedBox()),
      ...profileRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return router;
}

void main() {
  group('the code to look up', () {
    test('the printed number, upper-cased as ticket ids are', () {
      expect(certificateCodeFrom(' cert-7k3qf-x9pwm '), 'CERT-7K3QF-X9PWM');
      expect(certificateCodeFrom('CERT-7K3QF-X9PWM'), 'CERT-7K3QF-X9PWM');
    });

    test("the QR's text, a ticket id, a link to the certificate", () {
      expect(certificateCodeFrom('certificate:MOA-7K3QF-X9PWM'),
          'MOA-7K3QF-X9PWM');
      expect(certificateCodeFrom('MOA-7K3QF-X9PWM'), 'MOA-7K3QF-X9PWM');
      expect(
          certificateCodeFrom(
              'https://myotherapp.in/certificates/MOA-7K3QF-X9PWM'),
          'MOA-7K3QF-X9PWM');
    });

    test('nothing typed is nothing to look up', () {
      expect(certificateCodeFrom('   '), isNull);
      expect(certificateCodeFrom('certificate:'), isNull);
    });

    test("a certificate's own number and page", () {
      expect(_certificate.number, 'CERT-7K3QF-X9PWM');
      expect(_certificate.shareUrl,
          'https://myotherapp.in/certificates/MOA-7K3QF-X9PWM');
      expect(
        certificateShareText(_certificate),
        'My certificate for Robo Wars 2026, from Robotics Club: '
        'https://myotherapp.in/certificates/MOA-7K3QF-X9PWM\n'
        'Certificate number: CERT-7K3QF-X9PWM',
      );
    });
  });

  group("the server's answer", () {
    test('genuine: whose, for what, from whom, when', () {
      final check = CertificateVerification.fromJson(_valid);
      expect(check.result, CertificateCheck.valid);
      expect(check.attendeeName, 'Asha Menon');
      expect(check.eventName, 'Robo Wars 2026');
      expect(check.issuer, 'Robotics Club');
      expect(check.issuedAt, isNotNull);
    });

    test('revoked, and not found', () {
      expect(
          CertificateVerification.fromJson(
              {'valid': false, 'reason': 'revoked'}).result,
          CertificateCheck.revoked);
      expect(
          CertificateVerification.fromJson(
              {'valid': false, 'reason': 'not_found'}).result,
          CertificateCheck.notFound);
      // Never valid unless the server says so.
      expect(CertificateVerification.fromJson(const {}).isValid, isFalse);
    });

    test('GET /verify/certificates/{code}, without a session', () async {
      final api = useFakeApi();
      api.on('GET', '/verify/certificates/CERT-7K3QF-X9PWM', _valid);

      final check =
          await CertificateRemoteDataSourceImpl(APIService.instance.dio)
              .verify('CERT-7K3QF-X9PWM');

      final sent = api.requests.single;
      expect(sent.extra['skipAuth'], isTrue);
      expect(check.isValid, isTrue);
    });
  });

  group('the verify page', () {
    late RouteAdapter api;

    setUp(() => api = useFakeApi());

    testWidgets('a valid certificate: who, what, issuer, when', (tester) async {
      api.on('GET', '/verify/certificates/CERT-7K3QF-X9PWM', _valid);
      await _pump(tester, location: '/verify/certificates/cert-7k3qf-x9pwm');

      expect(find.byKey(const ValueKey('verify-result-valid')), findsOneWidget);
      expect(find.text('Genuine certificate'), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.text('Robo Wars 2026'), findsOneWidget);
      expect(find.text('Robotics Club'), findsOneWidget);
      expect(find.text('12 Oct 2026'), findsOneWidget);
    });

    testWidgets('a revoked certificate says it is no longer valid',
        (tester) async {
      api.on('GET', '/verify/certificates/CERT-AAAAA-BBBBB',
          {'valid': false, 'reason': 'revoked'});
      await _pump(tester, location: '/verify/certificates/CERT-AAAAA-BBBBB');

      expect(
          find.byKey(const ValueKey('verify-result-revoked')), findsOneWidget);
      expect(find.text('This certificate was revoked'), findsOneWidget);
      expect(find.text('Genuine certificate'), findsNothing);
    });

    testWidgets('a code someone gave you, typed in: not found', (tester) async {
      api.on('GET', '/verify/certificates/CERT-NOPE0-NOPE0',
          {'valid': false, 'reason': 'not_found'});
      await _pump(tester);

      // Nothing typed: said, and nothing sent.
      await tester.tap(find.byKey(const ValueKey('verify-submit')));
      await _settle(tester);
      expect(
          find.text('Type the number printed on the certificate, like '
              'CERT-7K3QF-X9PWM.'),
          findsOneWidget);
      expect(api.requests, isEmpty);

      await tester.enterText(
          find.byKey(const ValueKey('verify-code')), 'cert-nope0-nope0');
      await tester.tap(find.byKey(const ValueKey('verify-submit')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('verify-result-not-found')),
          findsOneWidget);
      expect(find.text('No certificate has this number'), findsOneWidget);
    });

    testWidgets('no connection: a way to try again', (tester) async {
      await _pump(tester, location: '/verify/certificates/CERT-7K3QF-X9PWM');
      // Unrouted: the fake answers 404 with no reason, which is not a
      // verdict on the certificate.
      expect(find.byKey(const ValueKey('verify-result-error')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group("a certificate's own page", () {
    setUp(() => useFakeApi());

    testWidgets('shares its page on the website, and checks itself',
        (tester) async {
      // Tall enough for the whole page to be built.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final shared = <String>[];
      await _pump(
        tester,
        home: CertificateDetailPage(certificate: _certificate),
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          certificateSharerProvider
              .overrideWithValue((text, {subject, origin}) async {
            shared.add(text);
          }),
        ],
      );

      expect(
          find.byWidgetPredicate((w) =>
              w is SelectableText &&
              w.data == 'Certificate number: CERT-7K3QF-X9PWM'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('certificate-share')));
      await _settle(tester);
      expect(shared.single,
          contains('https://myotherapp.in/certificates/MOA-7K3QF-X9PWM'));

      final verify = find.byKey(const ValueKey('certificate-verify'));
      await tester.ensureVisible(verify);
      await tester.pump();
      await tester.tap(verify);
      await _settle(tester);
      final page = tester
          .widget<CertificateVerifyPage>(find.byType(CertificateVerifyPage));
      expect(page.initialCode, 'CERT-7K3QF-X9PWM');
    });
  });
}
