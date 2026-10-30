import 'package:dio/dio.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/pages/past_events_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_render.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';

/// A certificate exists only where the organiser issued one.
///
/// A guest checked in at an event whose club did nothing at all, and both
/// the event page and the Past tab told them their certificate was ready:
/// a green "Attended and Certificate Generated" banner and a VIEW
/// CERTIFICATE button that answered "Certificate is being generated.
/// Please check back later." for ever, because nothing was being
/// generated. Both screens now read `has_certificate`, as My certificates
/// always has.

const _past = '/events/list?is_registered=true&is_ended=true&offset=0&limit=10';

const _certificateUrl = 'https://myotherapp.in/certificates/MOA-4KD9W';

Map<String, dynamic> _row(
  int id, {
  String name = 'Hack Night',
  bool attended = true,
  bool hasCertificate = false,
  bool revoked = false,
}) =>
    {
      'id': id,
      'name': name,
      'slug': 'event-$id',
      'club': {'id': 3, 'name': 'Tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': false,
      'event_datetime': '2020-12-01T10:00:00Z',
      'is_registered': true,
      'is_attended': attended,
      'ticket_id': 'MOA-4KD9W-22XQZ',
      'has_certificate': hasCertificate,
      'certificate_revoked': revoked,
      if (hasCertificate) 'certificate_url': _certificateUrl,
    };

/// The event page's own payload (`/events/info/{id}`) for the same event.
Map<String, dynamic> _info({
  bool attended = true,
  bool hasCertificate = false,
  bool revoked = false,
}) =>
    {
      ..._row(7,
          attended: attended, hasCertificate: hasCertificate, revoked: revoked),
      'poster': null,
      'duration': 2.5,
      'location_name': 'CET',
      'reg_fee': 0,
      'has_prize': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': null,
      'additional_details': const [],
      'rating': 0,
      'total_rating': 0,
      'is_paid': true,
      'ticket_url': 'https://myotherapp.in/tickets/T-1',
    };

/// No tickets kept on the phone: the lists' background sync has nothing
/// to do.
class _NoTickets extends SavedTicketsRepository {
  _NoTickets()
      : super(
          dio: Dio(),
          local: SavedTicketsLocalDataSource(MemoryStorage()),
        );

  @override
  Future<List<SavedTicket>> saved() async => const [];

  @override
  Future<List<SavedTicket>> refresh() async => const [];
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [page] inside a router, recording where it goes.
Future<List<String>> _pump(WidgetTester tester, Widget page) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final went = <String>[];
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: page)),
    GoRoute(
        path: '/events/:id',
        builder: (_, s) {
          went.add(s.uri.path);
          return const Scaffold(body: Text('the event'));
        }),
    GoRoute(
        path: '/certificates/:id',
        builder: (_, s) {
          went.add(s.uri.path);
          return const Scaffold(body: Text('the certificate'));
        }),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedTicketsRepositoryProvider.overrideWithValue(_NoTickets()),
      ticketImagesProvider.overrideWithValue(MemoryTicketImages()),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return went;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('the event page, checked in', () {
    testWidgets('and the club issued nothing: attended, and who the '
        'certificate waits on -- no button to one', (tester) async {
      api.on('GET', '/events/info/7', _info());
      await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(find.text('Attended'), findsOneWidget);
      expect(find.text('Attended and Certificate Generated'), findsNothing);
      expect(find.text(EventCard.pendingCertificateNote), findsOneWidget);
      expect(find.text('VIEW CERTIFICATE'), findsNothing);
    });

    testWidgets('and the organiser issued one: the button is back, and opens '
        'the certificate', (tester) async {
      api.on('GET', '/events/info/7', _info(hasCertificate: true));
      final went = await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(find.text('Attended and Certificate Issued'), findsOneWidget);
      expect(find.text(EventCard.pendingCertificateNote), findsNothing);
      await tester.tap(find.text('VIEW CERTIFICATE'));
      await _settle(tester);

      expect(went, ['/certificates/MOA-4KD9W']);
    });

    testWidgets('and the organiser took it back: said as withdrawn, not as '
        'one still to come', (tester) async {
      api.on('GET', '/events/info/7', _info(revoked: true));
      await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(find.text('Attended'), findsOneWidget);
      expect(find.text(EventCard.revokedCertificateNote), findsOneWidget);
      expect(find.text(EventCard.pendingCertificateNote), findsNothing);
      expect(find.text('VIEW CERTIFICATE'), findsNothing);
    });
  });

  group('the Past tab, an attended event', () {
    testWidgets('whose club issued nothing: Attended, with a line about the '
        'certificate and no button to one', (tester) async {
      api.on('GET', _past, {'items': [_row(1)]});
      await _pump(tester, const PastEventsPage());

      expect(find.text('Attended'), findsOneWidget);
      expect(find.text(EventCard.pendingCertificateNote), findsOneWidget);
      expect(find.text('VIEW CERTIFICATE'), findsNothing);
      expect(find.text('VIEW EVENT'), findsOneWidget);
    });

    testWidgets('whose organiser issued one: VIEW CERTIFICATE, which opens it',
        (tester) async {
      api.on('GET', _past, {
        'items': [_row(1, hasCertificate: true)]
      });
      final went = await _pump(tester, const PastEventsPage());

      expect(find.text(EventCard.pendingCertificateNote), findsNothing);
      await tester.tap(find.text('VIEW CERTIFICATE'));
      await _settle(tester);

      expect(went, ['/certificates/MOA-4KD9W']);
    });

    testWidgets('whose certificate was revoked: reads as withdrawn',
        (tester) async {
      api.on('GET', _past, {
        'items': [_row(1, revoked: true)]
      });
      await _pump(tester, const PastEventsPage());

      expect(find.text('Attended'), findsOneWidget);
      expect(find.text(EventCard.revokedCertificateNote), findsOneWidget);
      expect(find.text(EventCard.pendingCertificateNote), findsNothing);
      expect(find.text('VIEW CERTIFICATE'), findsNothing);
    });

    testWidgets('a certificate without a check-in (a speaker) still offers it',
        (tester) async {
      api.on('GET', _past, {
        'items': [_row(1, attended: false, hasCertificate: true)]
      });
      await _pump(tester, const PastEventsPage());

      expect(find.text('Attended'), findsOneWidget);
      expect(find.text('VIEW CERTIFICATE'), findsOneWidget);
    });
  });

  group('the card status for an event that has ended', () {
    test('comes from the certificate, never from the check-in', () {
      expect(endedCardStatus(_row(1, hasCertificate: true)),
          EventCardStatus.attended);
      expect(endedCardStatus(_row(1)), EventCardStatus.attendedNoCertificate);
      expect(endedCardStatus(_row(1, revoked: true)),
          EventCardStatus.certificateRevoked);
      expect(endedCardStatus(_row(1, attended: false)),
          EventCardStatus.notAttended);
      // A certificate and a revocation cannot both stand; the certificate
      // wins, as the server's `has_certificate` is the whole rule.
      expect(endedCardStatus(_row(1, hasCertificate: true, revoked: true)),
          EventCardStatus.attended);
    });
  });

  group("why the server refused a certificate, from the 403's error_code",
      () {
    DioException refused(int status, String body) => DioException(
          requestOptions: RequestOptions(path: '/events/certificates/x/image'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/events/certificates/x/image'),
            statusCode: status,
            // Asked for as bytes, so the envelope arrives as bytes.
            data: body.codeUnits,
          ),
        );

    test('CERTIFICATE_NOT_ISSUED: it waits on the organiser', () {
      final refusal = CertificateDocuments.refusalIn(refused(403,
          '{"message":"No certificate has been issued for this event yet.",'
          '"error_code":"CERTIFICATE_NOT_ISSUED"}'));

      expect(refusal, CertificateRefusal.notIssued);
      expect(CertificateRender.messageFor(refusal!),
          CertificateRender.notIssuedMessage);
    });

    test('CERTIFICATE_REVOKED reads differently: it is gone, not coming', () {
      final refusal = CertificateDocuments.refusalIn(refused(403,
          '{"message":"This certificate was revoked.",'
          '"error_code":"CERTIFICATE_REVOKED"}'));

      expect(refusal, CertificateRefusal.revoked);
      expect(CertificateRender.messageFor(refusal!),
          CertificateRender.revokedMessage);
      expect(CertificateRender.revokedMessage,
          isNot(CertificateRender.notIssuedMessage));
    });

    test('a refusal with no code, and an envelope already read as a map', () {
      expect(CertificateDocuments.refusalIn(refused(404, '{"message":"no"}')),
          CertificateRefusal.gone);
      expect(
          CertificateDocuments.refusalIn(DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: 403,
              data: const {'error_code': 'CERTIFICATE_REVOKED'},
            ),
          )),
          CertificateRefusal.revoked);
    });

    test('no answer at all is not a refusal', () {
      expect(
          CertificateDocuments.refusalIn(DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          )),
          isNull);
      expect(
          CertificateDocuments.refusalIn(refused(502, '{"message":"down"}')),
          isNull);
    });
  });
}
