import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

const _absent = Object();

Map<String, dynamic> _info({
  Object? isPaid = _absent,
  bool registered = true,
  bool attended = false,
  bool hasFee = true,
  String? regEnd,
  double rating = 0,
}) =>
    {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'poster': null,
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': hasFee,
      'reg_fee': 250,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': regEnd,
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': {}},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': [],
      'rating': rating,
      'total_rating': rating > 0 ? 4 : 0,
      'is_registered': registered,
      'is_attended': attended,
      'ticket_url': registered ? 'https://myotherapp.in/tickets/T-1' : null,
      if (isPaid != _absent) 'is_paid': isPaid,
    };

Future<FakePaymentRepository> _pump(WidgetTester tester,
    {String? initialStatus}) async {
  final payments = FakePaymentRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(payments),
    ],
    child: MaterialApp(
      home: IndividualEventPage(eventId: 7, initialStatus: initialStatus),
    ),
  ));
  // Not pumpAndSettle: the loading shimmer runs until the event arrives.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return payments;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('an unpaid registration offers the payment, not a ticket',
      (tester) async {
    api.on('GET', '/events/info/7', _info(isPaid: false));
    await _pump(tester);

    expect(find.text('FINISH PAYMENT'), findsOneWidget);
    expect(find.text('VIEW TICKET'), findsNothing);
  });

  testWidgets('once registration has closed, an unpaid registration says so',
      (tester) async {
    // The server refuses to register again after the deadline, and that is
    // the way to the payment.
    api.on('GET', '/events/info/7',
        _info(isPaid: false, regEnd: '2020-01-01T00:00:00Z'));
    await _pump(tester);

    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'REGISTRATION CLOSED'));
    expect(button.onPressed, isNull);
    expect(find.text('VIEW TICKET'), findsNothing);
  });

  testWidgets('a server without is_paid shows the ticket, as before',
      (tester) async {
    api.on('GET', '/events/info/7', _info());
    await _pump(tester);

    expect(find.text('VIEW TICKET'), findsOneWidget);
    expect(find.text('FINISH PAYMENT'), findsNothing);
  });

  testWidgets(
      'Finish payment registers again, pays that registration, and refreshes '
      'into the ticket', (tester) async {
    api
      ..on('GET', '/events/info/7', _info(isPaid: false))
      ..on('GET', '/events/info/7', _info(isPaid: true))
      ..on('POST', '/events/registration/7/register', {
        'event_id': 7,
        'event_registration_id': 'reg-1',
        'pay_amount': 250.0,
        'ticket_id': 'T-1',
        'full_name': 'Asha Menon',
        'email': 'asha@example.com',
        'phone': '9876543210',
      });
    final payments = await _pump(tester);
    // Paid already (in another tab, say): no checkout to open, and the
    // test never reaches the Razorpay plugin.
    payments.order = Either.left(const AlreadyPaidFailure());

    await tester.tap(find.text('FINISH PAYMENT'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final register = api.sent('POST', '/events/registration/7/register');
    expect(register, hasLength(1));
    expect(register.single.data, {
      'full_name': 'Asha Menon',
      'email': 'asha@example.com',
      'phone': '9876543210',
      'additional_details': <String, String>{},
    });
    expect(payments.orders, [(7, 'reg-1')]);
    expect(
        find.text('Payment received. Your ticket is ready.'), findsOneWidget);
    expect(find.text('VIEW TICKET'), findsOneWidget);
    expect(find.text('FINISH PAYMENT'), findsNothing);
  });

  testWidgets('opened from "Finish payment" on a list, it starts paying',
      (tester) async {
    // An older server: the list knew it was unpaid, the event page can't.
    api
      ..on('GET', '/events/info/7', _info())
      ..on('POST', '/events/registration/7/register',
          {'event_registration_id': 'reg-1', 'pay_amount': 250.0});
    final payments = FakePaymentRepository()
      ..order = Either.left(const AlreadyPaidFailure());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        paymentRepositoryProvider.overrideWithValue(payments),
      ],
      child: const MaterialApp(
        home: IndividualEventPage(eventId: 7, initialStatus: 'finishPayment'),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(payments.orders, [(7, 'reg-1')]);
    expect(find.text('VIEW TICKET'), findsOneWidget);
  });

  testWidgets('a full event says so when the payment is attempted',
      (tester) async {
    api
      ..on('GET', '/events/info/7', _info(isPaid: false))
      ..on('POST', '/events/registration/7/register',
          {'message': 'Event is full'},
          status: 400);
    await _pump(tester);

    await tester.tap(find.text('FINISH PAYMENT'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('This event is full'), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('an event without a deadline is open for registration',
      (tester) async {
    api.on('GET', '/events/info/7', _info(registered: false, isPaid: null));
    await _pump(tester);

    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'REGISTER NOW'));
    expect(button.onPressed, isNotNull);
    expect(find.text('Registration details not available'), findsNothing);
  });

  testWidgets('share is back, and the dead "View All Reviews" is gone',
      (tester) async {
    api.on('GET', '/events/info/7',
        _info(attended: true, isPaid: true, rating: 4.5));
    await _pump(tester);

    expect(find.byTooltip('Share event'), findsOneWidget);
    expect(find.text('4.5 RATED'), findsOneWidget);
    expect(find.text('View All Reviews'), findsNothing);
  });
}
