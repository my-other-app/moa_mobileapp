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

/// A certificate's public id, the end of its link. Case matters.
const _publicId = 'q7Lk2Vb9_xR4mT0aZ-c8NwPe';
const _page = 'https://myotherapp.in/certificates/$_publicId';

/// As the server lists it: its own number and its page, neither made
/// from the ticket id.
final _certificate = Certificate(
  ticketId: 'MOA-9ARSE-J4TEG',
  number: 'CERT-7K3QF-X9PWM',
  shareUrl: _page,
  eventId: 7,
  eventName: 'Robo Wars 2026',
  clubName: 'Robotics Club',
  issuedOn: DateTime(2026, 10, 12),
);

Certificate _without({bool number = false, bool page = false}) => Certificate(
      ticketId: 'MOA-9ARSE-J4TEG',
      number: number ? 'CERT-7K3QF-X9PWM' : null,
      shareUrl: page ? _page : null,
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
    test('the printed number, upper-cased, with or without its dashes', () {
      expect(certificateCodeFrom(' cert-7k3qf-x9pwm '), 'CERT-7K3QF-X9PWM');
      expect(certificateCodeFrom('CERT-7K3QF-X9PWM'), 'CERT-7K3QF-X9PWM');
      expect(certificateCodeFrom('cert 7k3qf x9pwm'), 'CERT-7K3QF-X9PWM');
      expect(certificateCodeFrom('CERT7K3QFX9PWM'), 'CERT-7K3QF-X9PWM');
      expect(isCertificateNumber('CERT-7K3QF-X9PWM'), isTrue);
      expect(isCertificateNumber(_publicId), isFalse);
    });

    test("the QR's link to the verifier gives the number", () {
      expect(
          certificateCodeFrom('https://myotherapp.in/verify/CERT-7K3QF-X9PWM'),
          'CERT-7K3QF-X9PWM');
      expect(
          certificateCodeFrom(
              'https://myotherapp.in/verify/certificates/CERT-7K3QF-X9PWM'),
          'CERT-7K3QF-X9PWM');
    });

    test("a link to the certificate's page gives its public id, case kept",
        () {
      expect(certificateCodeFrom(_page), _publicId);
      expect(certificateCodeFrom('  $_page?utm_source=wa#top '), _publicId);
      expect(certificateCodeFrom('myotherapp.in/certificates/$_publicId/'),
          _publicId);
      expect(certificateCodeFrom(_publicId), _publicId);
      expect(isCertificateNumber(certificateCodeFrom(_page)!), isFalse);
    });

    test('a ticket id, or what an older QR held, is not looked up', () {
      expect(certificateCodeFrom('certificate:MOA-7K3QF-X9PWM'), isNull);
      expect(certificateCodeFrom('MOA-7K3QF-X9PWM'), isNull);
      expect(
          certificateCodeFrom(
              'https://myotherapp.in/certificates/MOA-7K3QF-X9PWM'),
          isNull);
      expect(certificateCodeFrom('hello'), isNull);
    });

    test('the message a holder shares, pasted whole: its link', () {
      expect(
          certificateCodeFrom('My certificate for Robo Wars 2026, from '
              'Robotics Club: $_page\nCertificate number: CERT-7K3QF-X9PWM'),
          _publicId);
      expect(certificateCodeFrom('Certificate number: cert-7k3qf-x9pwm'),
          'CERT-7K3QF-X9PWM');
      // "Certificate" itself is not a number.
      expect(certificateCodeFrom('Certificate number'), isNull);
    });

    test('nothing typed is nothing to look up', () {
      expect(certificateCodeFrom('   '), isNull);
      expect(certificateCodeFrom('certificate:'), isNull);
      expect(certificateCodeFrom('https://myotherapp.in/'), isNull);
    });

    test("a certificate's own number and page, as the server sent them", () {
      expect(_certificate.number, 'CERT-7K3QF-X9PWM');
      expect(_certificate.shareUrl, _page);
      expect(canShareCertificate(_certificate), isTrue);
      expect(
        certificateShareText(_certificate),
        'My certificate for Robo Wars 2026, from Robotics Club: '
        '$_page\n'
        'Certificate number: CERT-7K3QF-X9PWM',
      );
      expect(certificateShareText(_certificate),
          isNot(contains(_certificate.ticketId)));
    });

    test('no page: nothing to share; no number: no number line', () {
      expect(canShareCertificate(_without(number: true)), isFalse);
      expect(certificateShareText(_without(number: true)), isNull);
      expect(
        certificateShareText(_without(page: true)),
        'My certificate for Robo Wars 2026, from Robotics Club: $_page',
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
      final revoked = CertificateVerification.fromJson({
        'valid': false,
        'reason': 'revoked',
        'number': 'CERT-AAAAA-BBBBB',
        'event_name': 'Robo Wars 2026',
        'org_name': 'Robotics Club',
        'org_slug': 'robotics-club',
      });
      expect(revoked.result, CertificateCheck.revoked);
      expect(revoked.eventName, 'Robo Wars 2026');
      expect(revoked.issuer, 'Robotics Club');
      expect(revoked.issuerSlug, 'robotics-club');
      expect(revoked.attendeeName, isNull);
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

    test('by public id, sent exactly as it is', () async {
      final api = useFakeApi();
      api.on('GET', '/verify/certificates/$_publicId', _valid);

      final check =
          await CertificateRemoteDataSourceImpl(APIService.instance.dio)
              .verify(_publicId);

      expect(api.requests.single.path, '/verify/certificates/$_publicId');
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
      api.on('GET', '/verify/certificates/CERT-AAAAA-BBBBB', {
        'valid': false,
        'reason': 'revoked',
        'number': 'CERT-AAAAA-BBBBB',
        'event_name': 'Robo Wars 2026',
        'org_name': 'Robotics Club',
      });
      await _pump(tester, location: '/verify/certificates/CERT-AAAAA-BBBBB');

      expect(
          find.byKey(const ValueKey('verify-result-revoked')), findsOneWidget);
      expect(find.text('This certificate was revoked'), findsOneWidget);
      expect(find.text('Genuine certificate'), findsNothing);
      // Which event and club took it back; never whose it was.
      expect(find.text('Robo Wars 2026'), findsOneWidget);
      expect(find.text('Robotics Club'), findsOneWidget);
      expect(find.text('Awarded to'), findsNothing);
    });

    testWidgets("a link to a certificate's page is checked by its public id",
        (tester) async {
      api.on('GET', '/verify/certificates/$_publicId', _valid);
      await _pump(tester);

      await tester.enterText(find.byKey(const ValueKey('verify-code')), _page);
      await tester.tap(find.byKey(const ValueKey('verify-submit')));
      await _settle(tester);

      expect(api.requests.single.path, '/verify/certificates/$_publicId');
      expect(find.byKey(const ValueKey('verify-result-valid')), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);
    });

    testWidgets('a link no certificate has: said as a link, not a number',
        (tester) async {
      api.on('GET', '/verify/certificates/$_publicId',
          {'valid': false, 'reason': 'not_found'});
      await _pump(tester, location: '/verify/certificates/$_publicId');

      expect(find.byKey(const ValueKey('verify-result-not-found')),
          findsOneWidget);
      expect(find.text('No certificate has this link'), findsOneWidget);
      expect(find.text('No certificate has this number'), findsNothing);
    });

    testWidgets("a ticket id is not a certificate's code: said, and not sent",
        (tester) async {
      await _pump(tester);

      await tester.enterText(
          find.byKey(const ValueKey('verify-code')), 'MOA-7K3QF-X9PWM');
      await tester.tap(find.byKey(const ValueKey('verify-submit')));
      await _settle(tester);

      expect(find.text(CertificateVerifyPage.notACode), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets("opened with what an older QR held: said, and not sent",
        (tester) async {
      await _pump(tester,
          location: '/verify/certificates/certificate:MOA-7K3QF-X9PWM');

      expect(find.text(CertificateVerifyPage.notACode), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-result-not-found')),
          findsNothing);
      expect(api.requests, isEmpty);
    });

    testWidgets('a code someone gave you, typed in: not found', (tester) async {
      api.on('GET', '/verify/certificates/CERT-NOPE0-NOPE0',
          {'valid': false, 'reason': 'not_found'});
      await _pump(tester);

      // Nothing typed: said, and nothing sent.
      await tester.tap(find.byKey(const ValueKey('verify-submit')));
      await _settle(tester);
      expect(find.text(CertificateVerifyPage.notACode), findsOneWidget);
      expect(api.requests, isEmpty);

      await tester.enterText(
          find.byKey(const ValueKey('verify-code')), 'cert-nope0-nope0');
      await tester.tap(find.byKey(const ValueKey('verify-submit')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('verify-result-not-found')),
          findsOneWidget);
      expect(find.text('No certificate has this number'), findsOneWidget);
      expect(api.requests.single.path, '/verify/certificates/CERT-NOPE0-NOPE0');
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

    Future<List<String>> pumpPage(
        WidgetTester tester, Certificate certificate) async {
      // Tall enough for the whole page to be built.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final shared = <String>[];
      await _pump(
        tester,
        home: CertificateDetailPage(certificate: certificate),
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          certificateSharerProvider
              .overrideWithValue((text, {subject, origin, pdfPath}) async {
            shared.add(text);
          }),
        ],
      );
      return shared;
    }

    Finder numberLine() => find.byWidgetPredicate((w) =>
        w is SelectableText &&
        (w.data ?? '').startsWith('Certificate number:'));

    testWidgets("shares the server's page, shows its number, and checks itself",
        (tester) async {
      final shared = await pumpPage(tester, _certificate);

      expect(
          find.byWidgetPredicate((w) =>
              w is SelectableText &&
              w.data == 'Certificate number: CERT-7K3QF-X9PWM'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('certificate-share')));
      await _settle(tester);
      expect(shared.single, contains(_page));
      expect(shared.single, isNot(contains(_certificate.ticketId)));

      final verify = find.byKey(const ValueKey('certificate-verify'));
      await tester.ensureVisible(verify);
      await tester.pump();
      await tester.tap(verify);
      await _settle(tester);
      final page = tester
          .widget<CertificateVerifyPage>(find.byType(CertificateVerifyPage));
      expect(page.initialCode, 'CERT-7K3QF-X9PWM');
    });

    testWidgets('no certificate_url: no share action', (tester) async {
      await pumpPage(tester, _without(number: true));

      expect(find.byKey(const ValueKey('certificate-share')), findsNothing);
      expect(find.byTooltip('Share certificate'), findsNothing);
      // The number the server sent is still shown.
      expect(numberLine(), findsOneWidget);
    });

    testWidgets('no certificate_no: no number, and it checks itself by its '
        'page', (tester) async {
      await pumpPage(tester, _without(page: true));

      expect(numberLine(), findsNothing);
      expect(find.textContaining('CERT-'), findsNothing);
      expect(find.byKey(const ValueKey('certificate-share')), findsOneWidget);

      final verify = find.byKey(const ValueKey('certificate-verify'));
      await tester.ensureVisible(verify);
      await tester.pump();
      await tester.tap(verify);
      await _settle(tester);
      expect(
          tester
              .widget<CertificateVerifyPage>(find.byType(CertificateVerifyPage))
              .initialCode,
          _publicId);
    });

    testWidgets('neither: no share, no number, nothing to check it by',
        (tester) async {
      await pumpPage(tester, _without());

      expect(find.byKey(const ValueKey('certificate-share')), findsNothing);
      expect(numberLine(), findsNothing);
      expect(find.byKey(const ValueKey('certificate-verify')), findsNothing);
      // Never the ticket id in its place.
      expect(find.textContaining('9ARSE-J4TEG'), findsNothing);
    });
  });
}
