import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/home/presentation/widgets/at_event_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

/// "You're at {event} · People like you" at the top of DISCOVER: from the
/// tickets already on the phone, only while checked in at an event that
/// is on, and only once the list has answered.

final _now = DateTime(2026, 10, 22, 19, 0);

SavedTicket _ticket({
  required DateTime startsAt,
  RegistrationStatus status = RegistrationStatus.attended,
  bool revoked = false,
  int eventId = 7,
}) =>
    SavedTicket(
      code: 'MOA-$eventId',
      eventId: eventId,
      eventName: 'Hack Night',
      startsAt: startsAt,
      durationHours: 3,
      status: status,
      revoked: revoked,
    );

class _Tickets implements SavedTicketsRepository {
  _Tickets(this.tickets);

  final List<SavedTicket> tickets;

  @override
  Future<List<SavedTicket>> saved() async => tickets;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<List<String>> _pump(WidgetTester tester, List<SavedTicket> tickets,
    {bool signedIn = true}) async {
  final went = <String>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(body: AtEventBanner(now: () => _now)),
    ),
    GoRoute(
      path: '/events/:ref/people',
      builder: (_, s) {
        went.add(s.uri.toString());
        return const Scaffold(body: Text('the list'));
      },
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(signedIn),
      savedTicketsRepositoryProvider.overrideWithValue(_Tickets(tickets)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return went;
}

Map<String, dynamic> _list(int sharing) => {
      'event_id': 7,
      'event_name': 'Hack Night',
      'attendees': [
        for (var i = 0; i < sharing; i++)
          {'user_id': 40 + i, 'name': 'P$i', 'match_count': 1},
      ],
    };

void main() {
  final live = _now.subtract(const Duration(hours: 1));

  group('which ticket', () {
    test('checked in at one that is on', () {
      expect(checkedInNow([_ticket(startsAt: live)], _now)?.eventId, 7);
    });

    test('one starting within two hours counts; one days away does not', () {
      expect(
          checkedInNow(
              [_ticket(startsAt: _now.add(const Duration(minutes: 90)))], _now),
          isNotNull);
      expect(
          checkedInNow(
              [_ticket(startsAt: _now.add(const Duration(days: 2)))], _now),
          isNull);
    });

    test('not one only registered for, revoked, or over', () {
      expect(
          checkedInNow([
            _ticket(startsAt: live, status: RegistrationStatus.registered),
            _ticket(startsAt: live, revoked: true),
            _ticket(startsAt: _now.subtract(const Duration(hours: 6))),
          ], _now),
          isNull);
    });
  });

  testWidgets('checked in at an event that is on: where, and the way in',
      (tester) async {
    final api = useFakeApi()..on('GET', '/events/7/networking', _list(3));
    final went = await _pump(tester, [_ticket(startsAt: live)]);

    expect(find.byKey(AtEventBanner.bannerKey), findsOneWidget);
    expect(find.textContaining('You’re at Hack Night'), findsOneWidget);
    expect(find.textContaining('3 people like you'), findsOneWidget);
    expect(api.sent('GET', '/events/7/networking'), hasLength(1));

    await tester.tap(find.byKey(AtEventBanner.bannerKey));
    await _settle(tester);
    expect(went, ['/events/7/people']);
  });

  testWidgets('nobody sharing yet: still the way in', (tester) async {
    useFakeApi().on('GET', '/events/7/networking', _list(0));
    await _pump(tester, [_ticket(startsAt: live)]);
    expect(find.textContaining('People like you'), findsOneWidget);
  });

  testWidgets('an event without People Like You: no banner to a dead end',
      (tester) async {
    useFakeApi().on(
        'GET',
        '/events/7/networking',
        {'message': 'No', 'error_code': 'NETWORKING_UNAVAILABLE'},
        status: 403);
    await _pump(tester, [_ticket(startsAt: live)]);
    expect(find.byKey(AtEventBanner.bannerKey), findsNothing);
  });

  testWidgets('any other day: nothing, and nothing asked', (tester) async {
    final api = useFakeApi();
    await _pump(tester, [_ticket(startsAt: _now.add(const Duration(days: 2)))]);
    expect(find.byKey(AtEventBanner.bannerKey), findsNothing);
    expect(api.requests, isEmpty);
  });

  testWidgets('signed out: nothing, and nothing asked', (tester) async {
    final api = useFakeApi();
    await _pump(tester, [_ticket(startsAt: live)], signedIn: false);
    expect(find.byKey(AtEventBanner.bannerKey), findsNothing);
    expect(api.requests, isEmpty);
  });
}
