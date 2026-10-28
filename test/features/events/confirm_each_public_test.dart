import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/ticket_type_picker.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/waitlist_widgets.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/high_demand_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_page_fixtures.dart';
import 'events_fakes.dart';
import 'ticketing_model_test.dart' show ticketingBody;

// Events whose club reviews every registration, as the public see them
// (feature-register/approval-stats-contract.md, "Website and app", worded
// as review-wording-contract.md §1.1 says): "{Club} reviews every
// registration" in place of "Be the first to register", the club's "High
// demand" chip, and no waiting list at all.

/// Every type sold out, and -- as an older server may still say -- the
/// list open for VIP.
final _soldOut = ticketingBody(soldOut: true, types: [
  {'id': 12, 'name': 'Early bird', 'price': 199, 'status': 'sold_out'},
  {
    'id': 13,
    'name': 'VIP',
    'price': 999,
    'status': 'sold_out',
    'waitlist': true
  },
]);

/// `GET /discover/events/7` with the event's new fields.
Map<String, dynamic> _page({
  bool requiresApproval = false,
  bool highDemand = false,
  String status = 'upcoming',
  int going = 0,
  int seatsLeft = 120,
}) {
  final page = discoverEventPage(
      status: status, going: going, seatsLeft: seatsLeft, capacity: 120);
  final event = page['event'] as Map<String, dynamic>;
  if (requiresApproval) event['requires_approval'] = true;
  if (highDemand) event['high_demand'] = true;
  return page;
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
  ));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ApiException _refusal(String code, {Map<String, dynamic>? errors}) =>
    ApiException(
      message: 'Refused',
      statusCode: 409,
      errorCode: code,
      errors: errors,
    );

void main() {
  group('"{Club} reviews every registration"', () {
    test('in place of "Be the first to register", with the seats left', () {
      expect(
          seatsLine(
              going: 0, seatsLeft: 38, confirmsEach: true, clubName: 'Tinkerhub'),
          'Tinkerhub reviews every registration · 38 seats left');
      expect(seatsLine(going: 0, seatsLeft: 0, confirmsEach: true),
          'The club reviews every registration');
      expect(seatsLine(going: 0, confirmsEach: true, clubName: '  '),
          'The club reviews every registration');
    });

    test('once someone is going, the count, as before', () {
      expect(
          seatsLine(
              going: 12, seatsLeft: 38, confirmsEach: true, clubName: 'Tinkerhub'),
          '12 going · 38 seats left');
    });

    test('an event without the setting is as it was', () {
      expect(seatsLine(going: 0, seatsLeft: 0), 'Be the first to register');
      expect(seatsLine(going: 0, seatsLeft: 38), '38 seats left');
      expect(confirmsEachPlaceLine('Tinkerhub'),
          'Tinkerhub reviews every registration');
    });

    test('the full note, by the button and on the form', () {
      expect(
          reviewsEveryRegistrationNote('Tinkerhub'),
          'Tinkerhub reviews every registration and emails tickets to the '
          'people it confirms.');
      expect(
          reviewsEveryRegistrationNote(null),
          'The club reviews every registration and emails tickets to the '
          'people it confirms.');
    });

    testWidgets('on the event page, beside the seats left', (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', _page(requiresApproval: true));
      await _pumpPage(tester);

      expect(find.byKey(SeatsMeter.lineKey), findsOneWidget);
      expect(find.text('Tinkerhub reviews every registration · 120 seats left'),
          findsOneWidget);
      expect(find.textContaining('Be the first'), findsNothing);
    });
  });

  group('the High demand chip', () {
    test('shown while the event is to come or on, never after or when off',
        () {
      expect(showsHighDemand(highDemand: true), isTrue);
      expect(showsHighDemand(highDemand: false), isFalse);
      expect(showsHighDemand(highDemand: true, ended: true), isFalse);
      expect(showsHighDemand(highDemand: true, cancelled: true), isFalse);
    });

    test('read from the event page, the discover cards and list rows', () {
      expect(EventPageDetails.fromJson(_page(highDemand: true))!.highDemand,
          isTrue);
      expect(EventPageDetails.fromJson(_page())!.highDemand, isFalse);

      final card = parseEvent({
        'id': 1,
        'name': 'Hack Night',
        'requires_approval': true,
        'high_demand': true,
      })!;
      expect(card.requiresApproval, isTrue);
      expect(card.highDemand, isTrue);
      final plain = parseEvent({'id': 1, 'name': 'Hack Night'})!;
      expect(plain.requiresApproval, isFalse);
      expect(plain.highDemand, isFalse);

      expect(eventCardFromJson({'id': 1, 'high_demand': true}).highDemand,
          isTrue);
      expect(
          eventCardFromJson({'id': 1, 'high_demand': true, 'status': 'ended'})
              .highDemand,
          isFalse);
      expect(eventCardFromJson({'id': 1}).highDemand, isFalse);
    });

    testWidgets('on the event page, when the club has it on', (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', _page(highDemand: true));
      await _pumpPage(tester);
      expect(find.byKey(HighDemandChip.chipKey), findsOneWidget);
      expect(find.text('High demand'), findsOneWidget);
    });

    testWidgets('not without it', (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', _page());
      await _pumpPage(tester);
      expect(find.byKey(HighDemandChip.chipKey), findsNothing);
    });

    testWidgets('not once the event has ended', (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7',
            _page(highDemand: true, status: 'ended'));
      await _pumpPage(tester);
      expect(find.byKey(HighDemandChip.chipKey), findsNothing);
    });

    testWidgets('on a discover card, beside the status', (tester) async {
      Future<void> card(DiscoverEvent event) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: DiscoverEventCard(event: event))),
        ));
        await tester.pump();
      }

      await card(const DiscoverEvent(
          id: 1,
          name: 'Hack Night',
          status: DiscoverEventStatus.closingSoon,
          highDemand: true));
      expect(find.byKey(HighDemandChip.chipKey), findsOneWidget);
      expect(find.text('Closing soon'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'it fits the row');

      await card(const DiscoverEvent(
          id: 1,
          name: 'Hack Night',
          status: DiscoverEventStatus.ended,
          highDemand: true));
      expect(find.byKey(HighDemandChip.chipKey), findsNothing);

      await card(const DiscoverEvent(id: 1, name: 'Hack Night'));
      expect(find.byKey(HighDemandChip.chipKey), findsNothing);
    });

    testWidgets("on a feed card's poster", (tester) async {
      Future<void> card({required bool highDemand}) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventCard(
                title: 'Hack Night',
                organizer: 'Tinkerhub',
                tags: const ['Tech'],
                onTap: () {},
                orgImage: '',
                eventId: 7,
                clubId: 3,
                clubSlug: 'tinkerhub',
                eventSlug: 'hack-night',
                highDemand: highDemand,
              ),
            ),
          ),
        ));
        await tester.pump();
      }

      await card(highDemand: true);
      expect(find.byKey(HighDemandChip.chipKey), findsOneWidget);
      await card(highDemand: false);
      expect(find.byKey(HighDemandChip.chipKey), findsNothing);
    });

    testWidgets('readable in a dark theme too: its own colours',
        (tester) async {
      Color? background(WidgetTester tester) => ((tester
                  .widget<Container>(find.byKey(HighDemandChip.chipKey))
                  .decoration) as BoxDecoration)
          .color;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(body: HighDemandChip())));
      final dark = background(tester);
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const Scaffold(body: HighDemandChip())));
      // The theme eases from dark to light.
      await tester.pumpAndSettle();
      final light = background(tester);
      expect(dark, isNot(light));
      expect(dark!.computeLuminance(), lessThan(0.1));
      expect(light!.computeLuminance(), greaterThan(0.8));
    });
  });

  group('no waiting list', () {
    test("the tickets read the list as off, whatever an older server says",
        () {
      final t =
          EventTicketing.fromJson({..._soldOut, 'requires_approval': true})!;
      expect(t.requiresApproval, isTrue);
      expect(t.waitlistEnabled, isFalse);
      expect(t.types.every((type) => !type.waitlist), isTrue);
      expect(t.waitlistTypes, isEmpty);
      expect(t.canJoinWaitlist, isFalse);
      expect(t.types.last.statusLine, 'Sold out');

      final other = EventTicketing.fromJson(_soldOut)!;
      expect(other.canJoinWaitlist, isTrue, reason: 'other events as before');
      final off = other.withoutWaitlist();
      expect(off.canJoinWaitlist, isFalse);
      expect(off.requiresApproval, isTrue);
      expect(off.types.map((t) => t.name), ['Early bird', 'VIP']);
    });

    test('a request is never offered the list after a refusal', () {
      final full =
          _refusal(TicketingErrorCodes.eventFull, errors: {'waitlist': true});
      expect(describeRegistrationError(full).action,
          RegistrationAction.joinWaitlist);
      expect(describeRegistrationError(full, approval: true).action, isNull);
      final sold = _refusal(TicketingErrorCodes.ticketTypeSoldOut,
          errors: {'waitlist': true});
      expect(offersWaitlist(sold), isTrue);
      expect(offersWaitlist(sold, approval: true), isFalse);
      expect(describeRegistrationError(sold, approval: true).action, isNull);
    });

    test('409 WAITLIST_OFF_ON_APPROVAL_EVENTS, in plain words', () {
      expect(
          waitlistJoinProblem(
              _refusal(TicketingErrorCodes.waitlistOffOnApprovalEvents)),
          'This event has no waiting list: the club reviews every '
          "registration. Register instead, and they'll get back to you.");
      expect(
          waitlistJoinProblem(
              _refusal(TicketingErrorCodes.waitlistOffOnApprovalEvents),
              clubName: 'Tinkerhub'),
          'This event has no waiting list: Tinkerhub reviews every '
          "registration. Register instead, and they'll get back to you.");
    });

    testWidgets('the event page offers none, the tickets say only "Sold out"',
        (tester) async {
      final api = useFakeApi()
        ..on(
            'GET',
            '/events/info/7',
            eventInfo(extra: {
              'requires_approval': true,
              'ticketing': {..._soldOut, 'requires_approval': true},
            }));
      await _pumpPage(tester);

      expect(find.byKey(TicketTypesList.listKey), findsOneWidget);
      expect(find.text('JOIN THE WAITING LIST'), findsNothing);
      expect(find.byKey(const ValueKey('event-also-waitlist')), findsNothing);
      expect(find.text('Join the waiting list'), findsNothing);
      expect(find.textContaining('waiting list open'), findsNothing);
      expect(find.text('Sold out'), findsNWidgets(2));
      expect(api.sent('POST', '/events/7/waitlist'), isEmpty);
    });

    testWidgets('known only from the website page: still none',
        (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo(extra: {'ticketing': _soldOut}))
        ..on('GET', '/discover/events/7', _page(requiresApproval: true));
      await _pumpPage(tester);

      expect(find.text('JOIN THE WAITING LIST'), findsNothing);
      expect(find.byKey(const ValueKey('event-also-waitlist')), findsNothing);
      expect(find.textContaining('waiting list open'), findsNothing);
    });

    testWidgets('the same tickets on another event still offer it',
        (tester) async {
      useFakeApi()
          .on('GET', '/events/info/7', eventInfo(extra: {'ticketing': _soldOut}));
      await _pumpPage(tester);
      expect(find.text('JOIN THE WAITING LIST'), findsOneWidget);
    });

    testWidgets('a refused join says why, with no button to try again',
        (tester) async {
      useFakeApi().on('POST', '/events/7/waitlist', {
        'message': 'No waiting list on approval events',
        'error_code': 'WAITLIST_OFF_ON_APPROVAL_EVENTS',
      }, status: 409);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: JoinWaitlistForm(
            event: 7,
            ticketing: EventTicketing.fromJson(_soldOut),
            api: TicketingApi(),
            name: 'Asha Menon',
            email: 'asha@example.com',
            onJoined: (_) {},
          ),
        ),
      ));
      await tester.tap(find.byKey(JoinWaitlistForm.submitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(JoinWaitlistForm.errorKey), findsOneWidget);
      expect(find.text(waitlistOffOnApprovalProblem), findsOneWidget);
      expect(find.byKey(JoinWaitlistForm.submitKey), findsNothing);
    });
  });
}
