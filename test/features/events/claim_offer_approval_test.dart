import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/presentation/pages/claim_offer_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import '../payments/razorpay_flow_fakes.dart';
import 'events_fakes.dart';

const _offerPath = '/waitlist/offers/clm_1';

/// The claim view; `reason: "approved"` when the club confirmed the
/// person's request (feature-register `approvals-contract.md`).
Map<String, dynamic> _offer({
  String? reason,
  String status = 'offered',
  double? amount,
}) =>
    {
      'id': 'o-1',
      'status': status,
      'event': {
        'id': 7,
        'slug': 'hack-night',
        'name': 'Hack Night',
        'event_datetime': '2030-12-01T10:00:00Z',
        'location_name': 'CET',
        'poster': null,
        'club': {'name': 'Tinkerhub', 'slug': 'tinkerhub'},
      },
      'ticket_type': {'id': 3, 'name': 'Student', 'price': 199},
      'full_name': 'Asha Menon',
      'email': 'as•••@example.com',
      'expires_at': '2030-11-02T12:30:00Z',
      'needs_email': false,
      'needs_payment': true,
      'registration_id': null,
      if (reason != null) 'reason': reason,
      if (amount != null) 'amount': amount,
    };

Future<FakePaymentRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/claim/clm_1', routes: [
    GoRoute(
      path: '/claim/:token',
      builder: (_, state) =>
          ClaimOfferPage(token: state.pathParameters['token']!),
    ),
  ]);
  final payments = FakePaymentRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(payments),
      isAuthenticatedProvider.overrideWithValue(true),
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

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(ClaimOfferPage.titleKey)).data!;

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('reason "approved": the club confirmed your registration',
      (tester) async {
    api.on('GET', _offerPath, _offer(reason: 'approved'));
    await _pump(tester);

    expect(_title(tester), 'Tinkerhub confirmed your registration');
    expect(find.text('Your registration'), findsOneWidget,
        reason: 'the app bar');
    expect(find.text('A place opened up for you'), findsNothing);
    final payBy =
        tester.widget<Text>(find.byKey(ClaimOfferPage.payByKey)).data!;
    expect(payBy, startsWith('Pay ₹199 by '));
    expect(payBy, endsWith(' to get your ticket.'));
    expect(find.text('PAY ₹199'), findsOneWidget);
    expect(find.text("I can't come: cancel my registration"), findsOneWidget);
    expect(find.text('No thanks, give it to the next person'), findsNothing);
    expect(find.textContaining('place'), findsNothing);

    await tester.tap(find.byKey(ClaimOfferPage.declineKey));
    await tester.pumpAndSettle();
    expect(find.text('Cancel your registration?'), findsOneWidget);
    expect(
        find.text("Your ticket will go to someone else, and you can't undo "
            'this.'),
        findsOneWidget);
    expect(find.text('Keep my registration'), findsOneWidget);
    expect(find.text('Yes, cancel it'), findsOneWidget);
    expect(find.textContaining('next person in line'), findsNothing);
  });

  testWidgets('reason "approved", cancelled: said so', (tester) async {
    api
      ..on('GET', _offerPath, _offer(reason: 'approved'))
      ..on('POST', '/waitlist/offers/clm_1/decline', {'declined': true});
    await _pump(tester);

    await tester.tap(find.byKey(ClaimOfferPage.declineKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, cancel it'));
    await tester.pumpAndSettle();

    expect(find.text('Your registration was cancelled'), findsOneWidget);
    expect(find.textContaining('place'), findsNothing);
  });

  testWidgets('reason "approved", ran out: the registration expired',
      (tester) async {
    api.on('GET', _offerPath, _offer(reason: 'approved', status: 'expired'));
    await _pump(tester);

    expect(find.text('Your registration has expired'), findsOneWidget);
    expect(
        find.text("Tinkerhub confirmed your registration for Hack Night, but "
            "it wasn't paid in time. If registration is still open, you can "
            'register again.'),
        findsOneWidget);
    expect(find.text('This offer ran out'), findsNothing);
  });

  testWidgets(
      'the confirmed price (its code taken off) is shown, and claiming '
      'sends nothing of the name or code', (tester) async {
    final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
    api
      ..on('GET', _offerPath, _offer(reason: 'approved', amount: 159.2))
      ..on('POST', '/waitlist/offers/clm_1/claim', {
        'event_id': 7,
        'event_name': 'Hack Night',
        'event_registration_id': 'reg-1',
        'pay_amount': 159.2,
        'ticket_id': 'T-9',
        'full_name': 'Asha Menon',
        'email': 'asha@example.com',
        'ticket_type': {'id': 3, 'name': 'Student'},
      });
    final payments = await _pump(tester);

    expect(find.text('PAY ₹159.20'), findsOneWidget);
    expect(find.text('₹159.20'), findsOneWidget);
    expect(find.text('₹199'), findsNothing);
    expect(find.byKey(ClaimOfferPage.emailKey), findsNothing);

    await tester.tap(find.byKey(ClaimOfferPage.claimKey));
    await tester.pumpAndSettle();

    expect(api.sent('POST', '/waitlist/offers/clm_1/claim').single.data,
        <String, dynamic>{});
    expect(payments.orders, [(7, 'reg-1')]);
    expect(sheet.opened, hasLength(1));
    expect(find.text("You're in!"), findsOneWidget);
  });

  testWidgets('a confirmed ticket without an amount: the ticket\'s price',
      (tester) async {
    api.on('GET', _offerPath, _offer(reason: 'approved'));
    await _pump(tester);
    expect(find.text('PAY ₹199'), findsOneWidget);
  });

  testWidgets('reason "waitlist" is a waiting list\'s place, as no reason',
      (tester) async {
    api.on('GET', _offerPath, _offer(reason: 'waitlist', amount: 99));
    await _pump(tester);

    expect(_title(tester), 'A place opened up for you');
    expect(find.text('No thanks, give it to the next person'), findsOneWidget);
    expect(find.text('CLAIM AND PAY ₹199'), findsOneWidget,
        reason: "only a confirmed request's place costs its amount");
  });

  testWidgets('no reason: a waiting list\'s place, worded as before',
      (tester) async {
    api.on('GET', _offerPath, _offer());
    await _pump(tester);

    expect(_title(tester), 'A place opened up for you');
    expect(find.text('No thanks, give it to the next person'), findsOneWidget);
  });
}
