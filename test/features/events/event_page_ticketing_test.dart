import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/cancelled_notice.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/ticket_type_picker.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/waitlist_widgets.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';
import 'ticketing_model_test.dart' show ticketingBody;

Map<String, dynamic> _info({
  bool registered = false,
  bool? isPaid,
  bool hasFee = true,
  Map<String, dynamic>? ticketing,
  bool cancelled = false,
}) =>
    {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': hasFee,
      'reg_fee': 199,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': null,
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': const [],
      'rating': 0,
      'total_rating': 0,
      'is_registered': registered,
      'ticket_url': registered ? 'https://myotherapp.in/tickets/T-1' : null,
      'is_paid': isPaid,
      if (ticketing != null) 'ticketing': ticketing,
      if (cancelled) ...{
        'status': 'cancelled',
        'registration_open': false,
        'cancellation': {
          'reason': 'The venue flooded.',
          'cancelled_at': '2026-10-20T10:00:00+05:30',
        },
      },
    };

Future<void> _pump(WidgetTester tester) async {
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
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Every type sold out, the list open for VIP.
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

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('a cancelled event', () {
    testWidgets('says so with the reason, and nothing can be registered',
        (tester) async {
      api.on('GET', '/events/info/7', _info(cancelled: true));
      await _pump(tester);

      expect(find.byKey(CancelledNotice.noticeKey), findsOneWidget);
      expect(find.text(CancelledNotice.title), findsOneWidget);
      expect(find.text('The organisers said: The venue flooded.'),
          findsOneWidget);
      expect(find.text('EVENT CANCELLED'), findsOneWidget);
      expect(find.text('REGISTER NOW'), findsNothing);
      expect(find.byKey(const ValueKey('event-cancelled-refund')),
          findsNothing, reason: 'not registered: no refund to speak of');
    });

    testWidgets('a paid ticket: no longer valid, and the refund under way',
        (tester) async {
      api.on('GET', '/events/info/7',
          _info(cancelled: true, registered: true, isPaid: true));
      await _pump(tester);

      expect(find.text('Your ticket is no longer valid.'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-cancelled-refund')),
          findsOneWidget);
      expect(find.text('VIEW TICKET'), findsNothing);
      expect(find.text('Your payment is being refunded'), findsOneWidget);
    });

    testWidgets("the website page's word is enough", (tester) async {
      api
        ..on('GET', '/events/info/7', _info())
        ..on('GET', '/discover/events/7', {
          'event': {
            'id': 7,
            'slug': 'hack-night',
            'name': 'Hack Night',
            'starts_at': '2030-12-01T10:00:00Z',
            'ends_at': '2030-12-01T12:30:00Z',
            'status': 'cancelled',
            'registration_open': false,
            'cancellation': {'reason': 'Speaker unwell.'},
            'is_online': false,
            'has_fee': true,
            'going': 0,
            'interests': [],
            'contact': {},
          },
          'club': {'id': 3, 'name': 'Tinkerhub'},
          'speakers': [],
          'agenda': {'timezone': 'Asia/Kolkata', 'items': []},
        });
      await _pump(tester);

      expect(find.text('The organisers said: Speaker unwell.'), findsOneWidget);
      expect(find.text('EVENT CANCELLED'), findsOneWidget);
    });
  });

  group('ticket types and the waiting list', () {
    testWidgets('several types are listed with their prices', (tester) async {
      api.on('GET', '/events/info/7', _info(ticketing: ticketingBody()));
      await _pump(tester);

      expect(find.byKey(TicketTypesList.listKey), findsOneWidget);
      expect(find.text('Only 3 left'), findsOneWidget);
      expect(find.text('₹199 – ₹999'), findsOneWidget);
      // Early bird is on sale: register, or wait for the sold-out VIP.
      expect(find.text('REGISTER NOW'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-also-waitlist')), findsOneWidget);
    });

    testWidgets(
        'sold out with the list open: the button joins it, and the place '
        'in line shows after', (tester) async {
      api
        ..on('GET', '/events/info/7', _info(ticketing: _soldOut))
        ..on(
            'GET',
            '/events/info/7',
            _info(
                ticketing: {
              ..._soldOut,
              'viewer_waitlist': [
                {
                  'id': 'w-1',
                  'ticket_type_id': 13,
                  'ticket_type_name': 'VIP',
                  'status': 'waiting',
                  'position': 3,
                },
              ],
            }))
        ..on('POST', '/events/7/waitlist', {
          'id': 'w-1',
          'ticket_type_id': 13,
          'ticket_type_name': 'VIP',
          'status': 'waiting',
          'position': 3,
          'created': true,
        });
      await _pump(tester);

      await tester.tap(find.text('JOIN THE WAITING LIST'));
      await tester.pumpAndSettle();
      // The sheet, filled in from the profile; only VIP can be waited for.
      expect(find.text('For: VIP'), findsOneWidget);
      await tester.tap(find.byKey(JoinWaitlistForm.submitKey));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/events/7/waitlist').single.data, {
        'ticket_type_id': 13,
        'full_name': 'Asha Menon',
        'email': 'asha@example.com',
        'phone': '9876543210',
      });
      expect(
          find.text(
              "You're on the waiting list. You're #3 in line. We'll tell you when a place opens up."),
          findsOneWidget);
      expect(find.byKey(WaitlistPlacesCard.cardKey), findsOneWidget);
      expect(find.text("You're #3 in line for VIP."), findsOneWidget);
      expect(find.text("YOU'RE ON THE WAITING LIST"), findsOneWidget);
    });

    testWidgets('a refused join says why in the sheet', (tester) async {
      api
        ..on('GET', '/events/info/7', _info(ticketing: _soldOut))
        ..on('POST', '/events/7/waitlist', {
          'message': 'Tickets available',
          'error_code': 'WAITLIST_NOT_NEEDED',
          'errors': {'available': 2},
        }, status: 409);
      await _pump(tester);

      await tester.tap(find.text('JOIN THE WAITING LIST'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(JoinWaitlistForm.submitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(JoinWaitlistForm.errorKey), findsOneWidget);
      expect(find.text('Tickets are available again: you can register instead.'),
          findsOneWidget);
    });

    testWidgets('an offer held says until when; leaving asks first',
        (tester) async {
      final held = {
        ..._soldOut,
        'viewer_waitlist': [
          {
            'id': 'w-1',
            'ticket_type_id': 13,
            'ticket_type_name': 'VIP',
            'status': 'offered',
            'offer_expires_at': '2030-11-02T12:30:00Z',
          },
        ],
      };
      api
        ..on('GET', '/events/info/7', _info(ticketing: held))
        ..on('GET', '/events/info/7', _info(ticketing: _soldOut))
        ..on('DELETE', '/events/7/waitlist/me', {'left': 1});
      await _pump(tester);

      expect(find.text('A place is yours to claim'), findsOneWidget);
      expect(find.textContaining('is held for you until'), findsOneWidget);

      await tester.tap(find.byKey(WaitlistPlacesCard.leaveKey));
      await tester.pumpAndSettle();
      expect(find.text('Leave the waiting list?'), findsOneWidget);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', '/events/7/waitlist/me'), hasLength(1));
      expect(find.byKey(WaitlistPlacesCard.cardKey), findsNothing);
      expect(find.text('JOIN THE WAITING LIST'), findsOneWidget);
    });

    testWidgets('an older server: no ticketing, the page as it was',
        (tester) async {
      api.on('GET', '/events/info/7', _info());
      await _pump(tester);

      expect(find.byKey(TicketTypesList.listKey), findsNothing);
      expect(find.byKey(WaitlistPlacesCard.cardKey), findsNothing);
      expect(find.text('REGISTER NOW'), findsOneWidget);
      expect(find.text('₹ 199'), findsOneWidget);
    });
  });
}
