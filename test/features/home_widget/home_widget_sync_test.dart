import 'dart:convert';

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/registration_requests_api.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/pages/event_ticket_page.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/home_widget/data/next_up_store.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart';
import 'package:finnet/features/home_widget/presentation/home_widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The widgets' storage, kept in memory.
class _Store implements NextUpStore {
  final writes = <String>[];
  int redraws = 0;
  bool placed = false;

  Map<String, dynamic> get last => jsonDecode(writes.last) as Map<String, dynamic>;

  @override
  Future<void> write(String json) async => writes.add(json);

  @override
  Future<void> redraw() async => redraws++;

  @override
  Future<bool> isPlaced() async => placed;
}

class _Repo implements SavedTicketsRepository {
  _Repo(this.tickets);

  final List<SavedTicket> tickets;

  @override
  Future<List<SavedTicket>> saved() async => tickets;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The saved tickets, asking the server nothing.
class _Tickets extends SavedTicketsNotifier {
  _Tickets(List<SavedTicket> tickets) : super(_Repo(tickets));

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> refreshIfOlderThan(Duration age) => refresh();

  void set(List<SavedTicket> tickets) => state = tickets;
}

class _Requests extends RegistrationRequestsApi {
  List<RegistrationRequest> mineAnswer = const [];
  int asked = 0;

  @override
  Future<List<RegistrationRequest>?> savedMine() async => null;

  @override
  Future<List<RegistrationRequest>?> mine() async {
    asked++;
    return mineAnswer;
  }
}

SavedTicket _ticket(int eventId, String name, {DateTime? startsAt}) =>
    SavedTicket(
      code: 'MOA-CODE-$eventId',
      eventId: eventId,
      eventName: name,
      startsAt: startsAt ?? DateTime.now().add(const Duration(days: 2)),
      durationHours: 3,
      venue: 'Maker Space',
    );

final _signedIn = StateProvider<bool>((ref) => true);

void main() {
  group('HomeWidgetSync', () {
    test('writes what the widget shows, and the same thing once', () async {
      final store = _Store();
      final sync = HomeWidgetSync(store, now: () => DateTime.utc(2026, 11, 13));

      await sync.signedOut();
      await sync.signedOut();
      await sync.show(NextUpSnapshot.nothing);

      expect(store.writes, hasLength(2));
      expect(jsonDecode(store.writes.first)['state'], 'signed_out');
      expect(store.last['state'], 'nothing');
    });

    test('signing out puts the signed-out state on the widgets', () async {
      final store = _Store();
      await showSignedOutOnWidgets(store);
      expect(store.last['state'], 'signed_out');
      expect(store.last['items'], isEmpty);
    });
  });

  group('HomeWidgetSyncScope', () {
    late _Store store;
    late _Tickets tickets;
    late _Requests requests;
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester,
        {List<SavedTicket> saved = const [], bool placed = false}) async {
      store = _Store()..placed = placed;
      tickets = _Tickets(saved);
      requests = _Requests();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          nextUpStoreProvider.overrideWithValue(store),
          savedTicketsProvider.overrideWith((ref) => tickets),
          registrationRequestsApiProvider.overrideWithValue(requests),
          isAuthenticatedProvider.overrideWith((ref) => ref.watch(_signedIn)),
        ],
        child: const MaterialApp(
          home: HomeWidgetSyncScope(child: Text('the tabs')),
        ),
      ));
      container = ProviderScope.containerOf(tester.element(find.text('the tabs')));
      await tester.pumpAndSettle();
    }

    testWidgets('once the saved tickets are read, the next one is written',
        (tester) async {
      await pump(tester, saved: [_ticket(12, 'Hack Night')]);

      expect(store.writes, hasLength(1));
      expect(store.last['state'], 'upcoming');
      expect(store.last['items'][0]['name'], 'Hack Night');
      expect(store.last['items'][0]['link'],
          'https://myotherapp.in/events/12/ticket');
    });

    testWidgets('a new ticket, and signing out, are written as they happen',
        (tester) async {
      await pump(tester);
      expect(store.last['state'], 'nothing');

      tickets.set([_ticket(7, 'Design Jam')]);
      await tester.pump();
      expect(store.last['items'][0]['name'], 'Design Jam');

      container.read(_signedIn.notifier).state = false;
      await tester.pump();
      expect(store.last['state'], 'signed_out');
    });

    testWidgets('a registration under review shows when it is all there is',
        (tester) async {
      await pump(tester);
      container.read(myRegistrationRequestsProvider.notifier).state =
          MyRegistrationRequests(loaded: true, items: [
        RegistrationRequest(
          id: 'r1',
          status: RequestStatus.pending,
          token: 'secret-token',
          event: RequestEvent(
            id: 9,
            slug: 'design-jam-x1y2z3',
            name: 'Design Jam',
            eventDateTime: DateTime.now().add(const Duration(days: 1)),
          ),
        ),
      ]);
      await tester.pump();

      expect(store.last['items'][0]['badge'], 'Under review');
      expect(store.writes.last, isNot(contains('secret-token')));
    });

    testWidgets('back to the front: the widgets are drawn again',
        (tester) async {
      await pump(tester, saved: [_ticket(12, 'Hack Night')]);
      final before = store.redraws;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(store.redraws, before + 1);
      // Nothing changed: nothing written again.
      expect(store.writes, hasLength(1));
    });

    testWidgets('no widget on a screen: the registrations are not read for it',
        (tester) async {
      await pump(tester);
      expect(requests.asked, 0);
    });

    testWidgets('a widget on a screen: the registrations are read for it',
        (tester) async {
      await pump(tester, placed: true);
      expect(requests.asked, 1);
    });
  });

  group('the ticket page for an event (the widget\'s tap)', () {
    test('finds the ticket by its event; a usable one first', () {
      final revoked = SavedTicket(
          code: 'OLD', eventId: 5, eventName: 'Jam', revoked: true);
      final good = SavedTicket(code: 'NEW', eventId: 5, eventName: 'Jam');
      final other = SavedTicket(code: 'X', eventId: 6, eventName: 'Other');

      expect(savedTicketForEvent([revoked, other, good], 5)?.code, 'NEW');
      expect(savedTicketForEvent([revoked, other], 5)?.code, 'OLD');
      expect(savedTicketForEvent([other], 5), isNull);
      expect(savedTicketForEvent([good], null), isNull);
    });
  });
}
