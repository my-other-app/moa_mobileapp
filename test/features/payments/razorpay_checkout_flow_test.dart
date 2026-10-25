import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/config/env/env.dart';
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

Future<void> _settle(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The app's payments over the fake API: the real repository and data
/// source, so the order, the checkout and the verification are the app's.
final _payments = [
  paymentRemoteDataSourceProvider.overrideWith(
      (ref) => PaymentRemoteDataSourceImpl(APIService.instance.dio)),
];

Future<void> _pumpEvent(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ..._payments,
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
  ));
  await _settle(tester, 6);
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('Finish payment on the event page', () {
    testWidgets(
        "opens Razorpay with the club's key and the order, verifies the "
        'payment, and shows the ticket', (tester) async {
      final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
      api
        ..on('GET', '/events/info/7', paidEventInfo(isPaid: false))
        ..on('GET', '/events/info/7', paidEventInfo(isPaid: true))
        ..on('POST', '/payments/orders', paymentOrderBody())
        ..on('POST', '/payments/verify', {'status': 'paid'});
      await _pumpEvent(tester);

      await tester.tap(find.text('FINISH PAYMENT'));
      await _settle(tester);

      final order = api.sent('POST', '/payments/orders').single;
      expect(order.queryParameters, {'checkout': checkoutVersion});
      expect(order.data, {
        'source': 'event_registration',
        'payload': {'event_id': 7, 'event_registration_id': 'reg-1'},
      });

      expect(sheet.opened, [
        {
          'key': 'rzp_live_club',
          'order_id': 'order_1',
          'amount': 25000,
          'currency': 'INR',
          'name': 'MyOtherApp',
          'prefill': {
            'name': 'Asha Menon',
            'email': 'asha@example.com',
            'contact': '9876543210',
          },
        },
      ]);

      final verify = api.sent('POST', '/payments/verify').single;
      expect(verify.data, {
        'razorpay_order_id': 'order_1',
        'razorpay_payment_id': 'pay_1',
      });
      expect(verify.extra['skipAuth'], isTrue);

      expect(find.text('Payment received. Your ticket is ready.'),
          findsOneWidget);
      expect(find.text('VIEW TICKET'), findsOneWidget);
      expect(find.text('FINISH PAYMENT'), findsNothing);
    });

    testWidgets(
        "an older server's order carries no key: the app's own key opens it",
        (tester) async {
      final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
      api
        ..on('GET', '/events/info/7', paidEventInfo(isPaid: false))
        ..on('POST', '/payments/orders', paymentOrderBody(keyId: null))
        ..on('POST', '/payments/verify', {'status': 'paid'});
      await _pumpEvent(tester);

      await tester.tap(find.text('FINISH PAYMENT'));
      await _settle(tester);

      expect(sheet.opened.single['key'], Env.razorpayKeyId);
    });

    testWidgets(
        'closing the sheet without paying keeps the registration, says so, '
        'and verifies nothing', (tester) async {
      final sheet = FakeRazorpaySheet(razorpayCancelled)..install(tester);
      api
        ..on('GET', '/events/info/7', paidEventInfo(isPaid: false))
        ..on('POST', '/payments/orders', paymentOrderBody());
      await _pumpEvent(tester);

      await tester.tap(find.text('FINISH PAYMENT'));
      await _settle(tester);

      expect(sheet.opened, hasLength(1));
      expect(api.sent('POST', '/payments/verify'), isEmpty);
      expect(
          find.text('Payment not completed. Your registration is saved — '
              'tap Finish payment to try again.'),
          findsOneWidget);
      expect(find.text('FINISH PAYMENT'), findsOneWidget);
      expect(find.text('VIEW TICKET'), findsNothing);
    });

    testWidgets(
        'a payment the server could not verify is not shown as paid',
        (tester) async {
      FakeRazorpaySheet(razorpayPaid).install(tester);
      api
        ..on('GET', '/events/info/7', paidEventInfo(isPaid: false))
        ..on('POST', '/payments/orders', paymentOrderBody())
        ..on('POST', '/payments/verify',
            {'message': 'Signature mismatch', 'error_code': 'BAD_SIGNATURE'},
            status: 400);
      await _pumpEvent(tester);

      await tester.tap(find.text('FINISH PAYMENT'));
      await _settle(tester);

      expect(api.sent('POST', '/payments/verify'), hasLength(1));
      expect(find.text('Payment received. Your ticket is ready.'),
          findsNothing);
      expect(find.text('FINISH PAYMENT'), findsOneWidget);
    });
  });

  group('registering for a paid event', () {
    Future<List<String>> pumpForm(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(800, 3200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
      return went;
    }

    void registersOwing250() =>
        api.on('POST', '/events/registration/7/register', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'event_registration_id': 'reg-1',
          'pay_amount': 250,
          'ticket_id': 'T-1',
          'event_datetime': '2030-12-01T10:00:00Z',
          'full_name': 'Asha Menon',
        });

    testWidgets(
        'the form registers, Razorpay takes the fee, and the success screen '
        'follows', (tester) async {
      final sheet = FakeRazorpaySheet(razorpayPaid)..install(tester);
      registersOwing250();
      api
        ..on('POST', '/payments/orders', paymentOrderBody())
        ..on('POST', '/payments/verify', {'status': 'paid'});
      final went = await pumpForm(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/events/registration/7/register'),
          hasLength(1));
      expect(
          (api.sent('POST', '/payments/orders').single.data as Map)['payload'],
          {'event_id': 7, 'event_registration_id': 'reg-1'});
      expect(sheet.opened.single['amount'], 25000);
      expect(api.sent('POST', '/payments/verify'), hasLength(1));
      expect(went, ['/events/registration-success']);
    });

    testWidgets(
        'closing the sheet holds the place and stays on the form, with no '
        'success screen', (tester) async {
      FakeRazorpaySheet(razorpayCancelled).install(tester);
      registersOwing250();
      api.on('POST', '/payments/orders', paymentOrderBody());
      final went = await pumpForm(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
          find.text('Payment not completed. Your place is held — tap '
              'Continue to pay.'),
          findsOneWidget);
      expect(api.sent('POST', '/payments/verify'), isEmpty);
      expect(went, isEmpty);
      expect(find.text('Continue'), findsOneWidget);
    });
  });
}
