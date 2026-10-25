import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'razorpay_flow_fakes.dart';

/// The words a paused club payment account comes with.
const _paused =
    'Payments for this event are paused right now. Try again in a little while.';

/// `POST /payments/orders` when the club's own Razorpay account is paused.
const _gatewayUnavailable = {
  'message': "The club's payment account is not accepting payments",
  'error_code': 'GATEWAY_UNAVAILABLE',
};

final _payments = [
  paymentRemoteDataSourceProvider.overrideWith(
      (ref) => PaymentRemoteDataSourceImpl(APIService.instance.dio)),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  for (final status in [503, 409]) {
    testWidgets(
        'Finish payment on the event page: a plain message, no checkout '
        '($status)', (tester) async {
      final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
      tester.view
        ..physicalSize = const Size(800, 3000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      api
        ..on('GET', '/events/info/7', paidEventInfo(isPaid: false))
        ..on('POST', '/payments/orders', _gatewayUnavailable, status: status);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          ..._payments,
        ],
        child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
      ));
      await _settle(tester);

      await tester.tap(find.text('FINISH PAYMENT'));
      await _settle(tester);

      expect(api.sent('POST', '/payments/orders'), hasLength(1));
      expect(find.text(_paused), findsOneWidget);
      // Not the server's own words, nor an error class.
      expect(find.textContaining('not accepting'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(sheet.opened, isEmpty);
      expect(find.text('FINISH PAYMENT'), findsOneWidget);
    });
  }

  testWidgets(
      'registering for a paid event: registered, then the same message and '
      'no success screen', (tester) async {
    final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
    tester.view
      ..physicalSize = const Size(800, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api
      ..on('POST', '/events/registration/7/register', {
        'event_id': 7,
        'event_registration_id': 'reg-1',
        'pay_amount': 250,
        'ticket_id': 'T-1',
      })
      ..on('POST', '/payments/orders', _gatewayUnavailable, status: 503);
    final went = <String>[];
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const EventFormPage(
          eventId: 7,
          additionalDetails: [],
          hasFee: true,
          isOnline: false,
        ),
      ),
      GoRoute(
        path: '/events/registration-success',
        builder: (_, state) {
          went.add(state.uri.path);
          return const Scaffold(body: Text('Registered!'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        isAuthenticatedProvider.overrideWithValue(true),
        ..._payments,
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.sent('POST', '/events/registration/7/register'), hasLength(1));
    expect(find.text(_paused), findsOneWidget);
    expect(sheet.opened, isEmpty);
    expect(went, isEmpty);
  });
}
