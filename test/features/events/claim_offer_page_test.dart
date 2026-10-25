import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/presentation/pages/claim_offer_page.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/cancelled_notice.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import '../payments/razorpay_flow_fakes.dart';
import 'events_fakes.dart';

const _offerPath = '/waitlist/offers/tok_1';
const _claimPath = '/waitlist/offers/tok_1/claim';

Map<String, dynamic> _offer({
  String status = 'offered',
  double price = 0,
  bool needsEmail = false,
}) =>
    {
      'id': 'u-1',
      'status': status,
      'event': {
        'id': 7,
        'slug': 'hack-night',
        'name': 'Hack Night',
        'event_datetime': '2030-12-01T10:00:00Z',
        'location_name': 'CET',
        'poster': null,
      },
      'ticket_type': {
        'id': 12,
        'name': 'Early bird',
        'price': price,
        'currency': 'INR'
      },
      'full_name': 'Asha Menon',
      'email': needsEmail ? null : 'as•••@example.com',
      'phone': '•••••3210',
      'expires_at': '2030-11-02T12:30:00Z',
      'needs_email': needsEmail,
      'needs_payment': price > 0,
      'registration_id': null,
    };

Map<String, dynamic> _claimed({double pay = 0, bool guest = false}) => {
      'event_name': 'Hack Night',
      'event_id': 7,
      'event_registration_id': 'reg-1',
      'pay_amount': pay,
      'event_datetime': '2030-12-01T10:00:00Z',
      'ticket_id': 'T-9',
      'full_name': 'Asha Menon',
      'email': 'asha@example.com',
      'phone': '9876543210',
      'ticket_type': {'id': 12, 'name': 'Early bird'},
      'price': pay,
      'is_paid': pay == 0,
      if (guest) 'auth_token': {'access_token': 'guest', 'token_type': 'bearer'},
    };

Future<FakePaymentRepository> _pump(WidgetTester tester,
    {bool signedIn = true}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final payments = FakePaymentRepository();
  final router = GoRouter(initialLocation: '/claim/tok_1', routes: [
    GoRoute(
      path: '/claim/:token',
      builder: (_, state) =>
          ClaimOfferPage(token: state.pathParameters['token']!),
    ),
    GoRoute(
      path: '/tickets/:code',
      builder: (_, state) =>
          Scaffold(body: Text('Ticket ${state.pathParameters['code']}')),
    ),
    GoRoute(
      path: '/events/:ref',
      builder: (_, state) =>
          Scaffold(body: Text('Event ${state.pathParameters['ref']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(payments),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      savedTicketsRepositoryProvider.overrideWithValue(SavedTicketsRepository(
        dio: APIService.instance.dio,
        local: SavedTicketsLocalDataSource(MemoryStorage()),
      )),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return payments;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('a free place: claimed at once, then the ticket',
      (tester) async {
    api
      ..on('GET', _offerPath, _offer())
      ..on('POST', _claimPath, _claimed());
    await _pump(tester);

    expect(find.text('A place opened up for you'), findsOneWidget);
    expect(find.text('Early bird'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.textContaining('Held for you until'), findsOneWidget);
    expect(find.text('For Asha Menon · as•••@example.com'), findsOneWidget);

    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();

    expect(api.sent('POST', _claimPath).single.data, <String, dynamic>{});
    expect(find.byKey(ClaimOfferPage.doneKey), findsOneWidget);
    expect(find.text("You're in!"), findsOneWidget);
    await tester.tap(find.text('VIEW TICKET'));
    await tester.pumpAndSettle();
    expect(find.text('Ticket T-9'), findsOneWidget);
  });

  testWidgets('a paid place, for this account: claimed, then paid here',
      (tester) async {
    final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
    api
      ..on('GET', _offerPath, _offer(price: 199))
      ..on('POST', _claimPath, _claimed(pay: 199));
    final payments = await _pump(tester);

    expect(find.text('CLAIM AND PAY ₹199'), findsOneWidget);
    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();

    expect(payments.orders, [(7, 'reg-1')]);
    expect(sheet.opened, hasLength(1));
    expect(find.text("You're in!"), findsOneWidget);
  });

  testWidgets('a checkout closed: the place is still held, pay again',
      (tester) async {
    FakeRazorpaySheet(razorpayCancelled).install(tester);
    api
      ..on('GET', _offerPath, _offer(price: 199))
      ..on('POST', _claimPath, _claimed(pay: 199));
    await _pump(tester);

    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ClaimOfferPage.problemKey), findsOneWidget);
    expect(find.textContaining('Your place is held until'), findsOneWidget);
    expect(find.text('PAY ₹199'), findsOneWidget);
  });

  testWidgets(
      "another address's place (a guest's claim): paid on the website",
      (tester) async {
    api
      ..on('GET', _offerPath, _offer(price: 199))
      ..on('POST', _claimPath, _claimed(pay: 199, guest: true));
    final payments = await _pump(tester);

    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();

    expect(payments.orders, isEmpty);
    expect(find.byKey(ClaimOfferPage.websiteKey), findsOneWidget);
  });

  testWidgets('joined with a phone only: the email is asked, and sent',
      (tester) async {
    api
      ..on('GET', _offerPath, _offer(needsEmail: true))
      ..on('POST', _claimPath, _claimed());
    await _pump(tester, signedIn: false);

    expect(find.text('Sign in'), findsOneWidget);
    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();
    expect(find.text('Enter the email address for your ticket.'),
        findsOneWidget);
    expect(api.sent('POST', _claimPath), isEmpty);

    await tester.enterText(
        find.byKey(ClaimOfferPage.emailKey), 'asha@example.com');
    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();
    expect(api.sent('POST', _claimPath).single.data,
        {'email': 'asha@example.com'});
    expect(find.text("You're in!"), findsOneWidget);
  });

  testWidgets('No thanks passes the place on, once confirmed', (tester) async {
    api
      ..on('GET', _offerPath, _offer())
      ..on('POST', '/waitlist/offers/tok_1/decline', {'declined': true});
    await _pump(tester);

    await tester.tap(find.byKey(ClaimOfferPage.declineKey));
    await tester.pumpAndSettle();
    expect(find.text('Give up this place?'), findsOneWidget);
    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();

    expect(api.sent('POST', '/waitlist/offers/tok_1/decline'), hasLength(1));
    expect(find.text('Thanks for letting us know'), findsOneWidget);
  });

  testWidgets('an offer that ran out, or was claimed, says so',
      (tester) async {
    api.on('GET', _offerPath, _offer(status: 'expired'));
    await _pump(tester);

    expect(find.text('This offer ran out'), findsOneWidget);
    expect(find.byKey(ClaimOfferPage.claimKey), findsNothing);
    await tester.tap(find.text('See the event'));
    await tester.pumpAndSettle();
    expect(find.text('Event hack-night'), findsOneWidget);
  });

  testWidgets('claimed elsewhere meanwhile: read again, and said',
      (tester) async {
    api
      ..on('GET', _offerPath, _offer())
      ..on('GET', _offerPath, _offer(status: 'claimed'))
      ..on('POST', _claimPath,
          {'message': 'Claimed already', 'error_code': 'OFFER_CLAIMED'},
          status: 409);
    await _pump(tester);

    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();

    expect(find.text('This place has been claimed'), findsOneWidget);
  });

  testWidgets('an unknown token: the link is not valid', (tester) async {
    api.on('GET', _offerPath,
        {'message': 'This link is not valid.', 'error_code': 'OFFER_NOT_FOUND'},
        status: 404);
    await _pump(tester);

    expect(find.text("This link isn't valid"), findsOneWidget);
  });

  testWidgets('a cancelled event: said, and nothing to claim', (tester) async {
    api
      ..on('GET', _offerPath, _offer(price: 199))
      ..on('GET', '/discover/events/hack-night', {
        'event': {
          'id': 7,
          'status': 'cancelled',
          'cancellation': {'reason': 'The venue flooded.'},
        },
      });
    await _pump(tester);

    expect(find.byKey(CancelledNotice.noticeKey), findsOneWidget);
    expect(find.byKey(ClaimOfferPage.claimKey), findsNothing);
  });
}
