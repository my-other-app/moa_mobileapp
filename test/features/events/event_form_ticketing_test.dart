import 'package:dio/dio.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/discount_code_field.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/ticket_type_picker.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';
import 'ticketing_model_test.dart' show ticketingBody;

const _register = '/events/registration/7/register';
const _types = '/events/7/ticket-types';
const _check = '/events/7/discount-codes/check';

/// Two types on sale, as an event selling several sends them.
final _twoOnSale = ticketingBody(types: [
  {'id': 21, 'name': 'Student', 'price': 99, 'status': 'on_sale'},
  {'id': 22, 'name': 'General', 'price': 199, 'status': 'on_sale'},
]);

Map<String, dynamic> _registered({double pay = 0, String? type}) => {
      'event_id': 7,
      'event_name': 'Hack Night',
      'event_registration_id': 'reg-1',
      'pay_amount': pay,
      'ticket_id': 'T-1',
      'event_datetime': '2030-12-01T10:00:00Z',
      'full_name': 'Asha Menon',
      if (type != null) 'ticket_type': {'id': 12, 'name': type},
      'is_paid': pay == 0,
    };

/// The form, pushed from a page that keeps what it was closed with; the
/// success page says the ticket type it was handed.
Future<(List<Object?>, FakePaymentRepository)> _pump(WidgetTester tester,
    {int? linked}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final closedWith = <Object?>[];
  final payments = FakePaymentRepository();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async =>
                closedWith.add(await context.push<Object?>('/form')),
            child: const Text('Open form'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/form',
      builder: (_, __) => EventFormPage(
          eventId: 7, additionalDetails: const [], linkedTicketTypeId: linked),
    ),
    GoRoute(
      path: '/events/registration-success',
      builder: (_, state) => Scaffold(
          body: Text(
              'Registered! ${(state.extra as Map?)?['ticketType'] ?? ''}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(payments),
      isAuthenticatedProvider.overrideWithValue(true),
      savedTicketsRepositoryProvider.overrideWithValue(SavedTicketsRepository(
        dio: Dio(),
        local: SavedTicketsLocalDataSource(MemoryStorage()),
      )),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
  return (closedWith, payments);
}

Future<void> _continue(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _sent(RouteAdapter api) =>
    api.sent('POST', _register).single.data as Map<String, dynamic>;

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets(
      'a server without ticket types: no picker, no code, the old payload',
      (tester) async {
    api.on('POST', _register, _registered());
    await _pump(tester);

    expect(find.byType(TicketTypePicker), findsNothing);
    expect(find.byType(DiscountCodeField), findsNothing);
    await _continue(tester);

    final body = _sent(api);
    expect(body.containsKey('ticket_type_id'), isFalse);
    expect(body.containsKey('discount_code'), isFalse);
    expect(find.text('Registered! '), findsOneWidget);
  });

  testWidgets('one ticket type: no picker, nothing extra sent',
      (tester) async {
    api
      ..on('GET', _types, ticketingBody(requiresChoice: false, types: [
        {'id': 1, 'name': 'General admission', 'price': 0, 'status': 'on_sale'},
      ]))
      ..on('POST', _register, _registered());
    await _pump(tester);

    expect(find.byType(TicketTypePicker), findsNothing);
    expect(find.byType(DiscountCodeField), findsNothing, reason: 'free');
    await _continue(tester);
    expect(_sent(api).containsKey('ticket_type_id'), isFalse);
  });

  testWidgets('several types: one must be chosen, and it is sent',
      (tester) async {
    api
      ..on('GET', _types, _twoOnSale)
      ..on('POST', _register, _registered(type: 'General'));
    await _pump(tester);

    expect(find.byType(TicketTypePicker), findsOneWidget);
    expect(find.text('₹99'), findsOneWidget);
    await _continue(tester);
    expect(find.text('Choose a ticket.'), findsOneWidget);
    expect(api.sent('POST', _register), isEmpty);

    await tester.tap(find.byKey(TicketTypePicker.tileKey(22)));
    await tester.pump();
    expect(find.text('Choose a ticket.'), findsNothing);
    await _continue(tester);

    expect(_sent(api)['ticket_type_id'], 22);
    expect(find.text('Registered! General'), findsOneWidget);
  });

  testWidgets(
      'a code checked on Apply previews the price; the free ticket skips '
      'checkout on a paid event', (tester) async {
    api
      ..on('GET', _types, ticketingBody())
      ..on('POST', _check, {
        'code': 'EARLY20',
        'ticket_type_id': 12,
        'price': 199.0,
        'discount': 199.0,
        'amount': 0,
        'free': true,
      })
      ..on('POST', _register, _registered(type: 'Early bird'));
    final (_, payments) = await _pump(tester);

    // Only Early bird is on sale: it is chosen already.
    await tester.enterText(find.byKey(DiscountCodeField.fieldKey), 'early20');
    await tester.tap(find.byKey(DiscountCodeField.applyKey));
    await tester.pumpAndSettle();

    final check = api.sent('POST', _check).single.data as Map;
    expect(check['code'], 'early20');
    expect(check['ticket_type_id'], 12);
    expect(find.text('EARLY20 applied: your ticket is free.'), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('order-total'))).data,
        'Free');

    await _continue(tester);

    expect(_sent(api)['discount_code'], 'early20');
    expect(_sent(api)['ticket_type_id'], 12);
    expect(payments.orders, isEmpty, reason: 'pay_amount 0: no payment step');
    expect(find.text('Registered! Early bird'), findsOneWidget);
  });

  testWidgets('the code is checked once typing stops, and only once',
      (tester) async {
    api
      ..on('GET', _types, ticketingBody())
      ..on('POST', _check, {
        'code': 'EARLY20',
        'ticket_type_id': 12,
        'price': 199.0,
        'discount': 39.8,
        'amount': 159.2,
      });
    await _pump(tester);

    await tester.enterText(find.byKey(DiscountCodeField.fieldKey), 'EARLY20');
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.sent('POST', _check), isEmpty, reason: 'still typing');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.sent('POST', _check), hasLength(1));
    expect(find.textContaining('you pay ₹159.20'), findsOneWidget);

    // The same code again: answered from what was asked.
    await tester.tap(find.byKey(DiscountCodeField.applyKey));
    await tester.pumpAndSettle();
    expect(api.sent('POST', _check), hasLength(1));
  });

  testWidgets('a refused code says why; too many tries asks for a minute',
      (tester) async {
    api
      ..on('GET', _types, ticketingBody())
      ..on('POST', _check,
          {'message': 'Expired', 'error_code': 'DISCOUNT_CODE_EXPIRED'},
          status: 409)
      ..on('POST', _check, {'message': 'Too many requests'}, status: 429);
    await _pump(tester);

    await tester.enterText(find.byKey(DiscountCodeField.fieldKey), 'OLD10');
    await tester.tap(find.byKey(DiscountCodeField.applyKey));
    await tester.pumpAndSettle();
    expect(find.text('That code has expired.'), findsOneWidget);

    await tester.enterText(find.byKey(DiscountCodeField.fieldKey), 'NEW10');
    await tester.tap(find.byKey(DiscountCodeField.applyKey));
    await tester.pumpAndSettle();
    expect(find.text('Too many tries. Wait a minute, then try again.'),
        findsOneWidget);
  });

  testWidgets(
      'the registration refusing the code says so under it, not in a dialog',
      (tester) async {
    api
      ..on('GET', _types, ticketingBody())
      ..on('POST', _register,
          {'message': 'Used up', 'error_code': 'DISCOUNT_CODE_USED_UP'},
          status: 409);
    await _pump(tester);

    await tester.enterText(find.byKey(DiscountCodeField.fieldKey), 'GONE');
    await _continue(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(DiscountCodeField.errorKey), findsOneWidget);
    expect(find.text('That code has been used up.'), findsWidgets);

    // Another code: what was said about the last one goes.
    await tester.enterText(find.byKey(DiscountCodeField.fieldKey), 'NEXT');
    await tester.pump();
    expect(find.byKey(DiscountCodeField.errorKey), findsNothing);
  });

  testWidgets('a full event with its list open offers it, and closes with it',
      (tester) async {
    api.on('POST', _register, {
      'message': 'Event is full',
      'error_code': 'EVENT_FULL',
      'errors': {'max_participants': 100, 'waitlist': true},
    }, status: 400);
    final (closedWith, _) = await _pump(tester);

    await _continue(tester);
    expect(find.text('This event is full'), findsOneWidget);
    await tester.tap(find.text('Join the waiting list'));
    await tester.pumpAndSettle();

    expect(closedWith, [RegistrationAction.joinWaitlist]);
  });

  testWidgets('a sold-out type offers its waiting list from the picker',
      (tester) async {
    api.on('GET', _types, ticketingBody());
    final (closedWith, _) = await _pump(tester);

    expect(find.text('Sold out · waiting list open'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ticket-type-waitlist-13')));
    await tester.pumpAndSettle();

    expect(closedWith, [RegistrationAction.joinWaitlist]);
  });

  testWidgets('cancelled meanwhile: said, then back to the event',
      (tester) async {
    api.on('POST', _register, {
      'message': 'This event was cancelled',
      'error_code': 'REGISTRATIONS_CLOSED',
      'errors': {'closed_reason': 'cancelled'},
    }, status: 400);
    final (closedWith, _) = await _pump(tester);

    await _continue(tester);
    expect(find.text('This event was cancelled'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(closedWith, [null]);
  });

  testWidgets('a link to a hidden type lists it and chooses it',
      (tester) async {
    api
      ..on('GET', _types, ticketingBody(requiresChoice: false, types: [
        {'id': 1, 'name': 'General', 'price': 199, 'status': 'on_sale'},
        {
          'id': 30,
          'name': 'Speaker pass',
          'price': 0,
          'status': 'on_sale',
          'is_hidden': true
        },
      ]))
      ..on('POST', _register, _registered(type: 'Speaker pass'));
    await _pump(tester, linked: 30);

    expect(api.sent('GET', _types).single.queryParameters,
        {'ticket_type': 30});
    expect(find.text('Speaker pass'), findsOneWidget);
    await _continue(tester);
    expect(_sent(api)['ticket_type_id'], 30);
  });
}
