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
import 'events_fakes.dart';

const _offerPath = '/waitlist/offers/clm_1';

/// The claim view; `reason: "approved"` when the club confirmed the
/// person's request (feature-register `approvals-contract.md`).
Map<String, dynamic> _offer({String? reason, String status = 'offered'}) => {
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
    };

Future<void> _pump(WidgetTester tester) async {
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
  await tester.pumpWidget(ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
      savedTicketsRepositoryProvider.overrideWithValue(SavedTicketsRepository(
        dio: APIService.instance.dio,
        local: SavedTicketsLocalDataSource(MemoryStorage()),
      )),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(ClaimOfferPage.titleKey)).data!;

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('reason "approved": the club confirmed your place',
      (tester) async {
    api.on('GET', _offerPath, _offer(reason: 'approved'));
    await _pump(tester);

    expect(_title(tester), 'Tinkerhub confirmed your place');
    expect(find.text('A place opened up for you'), findsNothing);
    expect(find.text('CLAIM AND PAY ₹199'), findsOneWidget);
    expect(find.text("I can't make it, give up my place"), findsOneWidget);
    expect(find.text('No thanks, give it to the next person'), findsNothing);

    await tester.tap(find.byKey(ClaimOfferPage.declineKey));
    await tester.pumpAndSettle();
    expect(
        find.text("Tinkerhub can then offer it to someone else. You can't "
            'take it back.'),
        findsOneWidget);
    expect(find.textContaining('next person in line'), findsNothing);
  });

  testWidgets('reason "approved", ran out: the place was released',
      (tester) async {
    api.on('GET', _offerPath, _offer(reason: 'approved', status: 'expired'));
    await _pump(tester);

    expect(find.text('Your place was released'), findsOneWidget);
    expect(find.textContaining("the payment didn't arrive in time"),
        findsOneWidget);
    expect(find.text('This offer ran out'), findsNothing);
  });

  testWidgets('no reason: a waiting list\'s place, worded as before',
      (tester) async {
    api.on('GET', _offerPath, _offer());
    await _pump(tester);

    expect(_title(tester), 'A place opened up for you');
    expect(find.text('No thanks, give it to the next person'), findsOneWidget);
  });
}
