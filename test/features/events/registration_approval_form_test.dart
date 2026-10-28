import 'package:dio/dio.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/events_routes.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/pages/registration_request_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';
import 'registration_approval_model_test.dart' show requestBody;
import 'ticketing_model_test.dart' show ticketingBody;

const _register = '/events/registration/7/register';
const _types = '/events/7/ticket-types';

/// The answer to registering on an event whose club reviews every
/// registration.
Map<String, dynamic> _approval({double payAmount = 0}) => {
      'approval': {
        'id': 'req-1',
        'status': 'pending',
        'submitted_at': '2026-10-26T09:00:00Z',
        'token': 'tok_1',
        'status_url': 'https://myotherapp.in/requests/tok_1',
      },
      'event_registration_id': null,
      'auth_token': null,
      // Never charged at submission, whatever this says.
      'pay_amount': payAmount,
    };

Map<String, dynamic> _registered() => {
      'event_id': 7,
      'event_name': 'Hack Night',
      'event_registration_id': 'reg-1',
      'pay_amount': 0,
      'ticket_id': 'T-1',
      'event_datetime': '2030-12-01T10:00:00Z',
      'full_name': 'Asha Menon',
      'is_paid': true,
    };

/// The form, pushed from a page that keeps what it was closed with; the
/// success page and the request's screen as the app has them.
Future<(List<Object?>, FakePaymentRepository)> _pump(
  WidgetTester tester, {
  bool? requiresApproval,
  bool hasFee = false,
}) async {
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
        eventId: 7,
        additionalDetails: const [],
        hasFee: hasFee,
        isOnline: false,
        clubName: 'Tinkerhub',
        eventName: 'Hack Night',
        requiresApproval: requiresApproval,
      ),
    ),
    GoRoute(
      path: '/events/registration-success',
      builder: (_, __) => const Scaffold(body: Text('Registered!')),
    ),
    GoRoute(
      path: '/events/request-sent',
      redirect: requestSentRedirect,
      builder: buildRequestSentPage,
    ),
    GoRoute(
      path: '/events',
      builder: (_, __) => const Scaffold(body: Text('My events')),
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

Future<void> _submit(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _sent(RouteAdapter api) =>
    api.sent('POST', _register).single.data as Map<String, dynamic>;

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('every registration says it can take a request', (tester) async {
    api.on('POST', _register, _registered());
    await _pump(tester);

    // An event that doesn't review registrations: the form as it was.
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const ValueKey('form-approval-note')), findsNothing);
    await _submit(tester, 'Continue');

    expect(_sent(api)['accepts_approval'], isTrue);
    expect(find.text('Registered!'), findsOneWidget);
  });

  testWidgets(
      'the club reviews every registration: "Register", and how it works',
      (tester) async {
    api.on('POST', _register, _approval());
    await _pump(tester, requiresApproval: true);

    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Request a place'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(
        find.text('Tinkerhub reviews every registration and emails tickets '
            'to the people it confirms.'),
        findsOneWidget);
    expect(find.textContaining('confirms each place'), findsNothing);
  });

  group('add-ons', () {
    const catalog = {
      'enabled': true,
      'items': [
        {'id': 'tee', 'name': 'Hack Night tee', 'price': 399, 'variants': []},
      ],
    };

    testWidgets('a request carries none: no step, nothing sent',
        (tester) async {
      api
        ..on('GET', '/events/7/store/catalog', catalog)
        ..on('POST', _register, _approval());
      await _pump(tester, requiresApproval: true);

      expect(find.text('Hack Night tee'), findsNothing);
      expect(api.sent('GET', '/events/7/store/catalog'), isEmpty);
      await _submit(tester, 'Register');
      expect(_sent(api).containsKey('store'), isFalse);
    });

    testWidgets('said by the ticket types: hidden, and none sent',
        (tester) async {
      api
        ..on('GET', '/events/7/store/catalog', catalog)
        ..on('GET', _types, {
          ...ticketingBody(requiresChoice: false, types: [
            {'id': 1, 'name': 'General', 'price': 0, 'status': 'on_sale'},
          ]),
          'requires_approval': true,
        })
        ..on('POST', _register, _approval());
      await _pump(tester);

      expect(find.text('Hack Night tee'), findsNothing);
      await _submit(tester, 'Register');
      expect(_sent(api).containsKey('store'), isFalse);
    });

    testWidgets('an event that registers: the shelf as before', (tester) async {
      api
        ..on('GET', '/events/7/store/catalog', catalog)
        ..on('POST', _register, _registered());
      await _pump(tester);

      expect(find.text('Hack Night tee'), findsOneWidget);
      await _submit(tester, 'Continue');
      expect(_sent(api)['store'], isEmpty);
    });
  });

  testWidgets('the event\'s ticket types can say so too', (tester) async {
    api.on('GET', _types, {
      ...ticketingBody(requiresChoice: false, types: [
        {'id': 1, 'name': 'General', 'price': 0, 'status': 'on_sale'},
      ]),
      'requires_approval': true,
    });
    await _pump(tester);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets(
      'an approval answer: "You\'re registered!", not the ticket, and no '
      'payment even on a paid event', (tester) async {
    api
      ..on('POST', _register, _approval(payAmount: 199))
      ..on('GET', '/registration-requests/tok_1', requestBody());
    final (_, payments) =
        await _pump(tester, requiresApproval: true, hasFee: true);

    await _submit(tester, 'Register');

    expect(_sent(api)['accepts_approval'], isTrue);
    expect(payments.orders, isEmpty, reason: 'nothing is paid at submission');
    expect(find.text('Registered!'), findsNothing);
    final page = tester
        .widget<RegistrationRequestPage>(find.byType(RegistrationRequestPage));
    expect(page.justSent, isTrue);
    expect(page.token, 'tok_1');
    expect(page.initial!.status, RequestStatus.pending);
    expect(page.initial!.event!.id, 7);
    expect(page.initial!.event!.clubName, 'Tinkerhub');
    expect(page.sentTo, 'asha@example.com');
    expect(find.text('Under review'), findsOneWidget, reason: 'the chip');
    expect(find.text("You're registered!"), findsOneWidget);
    expect(
        find.text('Tinkerhub reviews every registration. If yours is '
            'confirmed, your ticket will come by email.'),
        findsOneWidget);
    expect(
        find.text("We've emailed you a link to check on your registration, "
            'at asha@example.com.'),
        findsOneWidget);
    expect(find.text('See your registration'), findsOneWidget);
    expect(find.text('Back to the event'), findsOneWidget);
    // Cancelling is on the registration's own screen.
    expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);
    expect(find.textContaining('waiting list'), findsNothing);
  });

  testWidgets(
      'an approval answer the form didn\'t expect is still a request '
      '(turned on after the page was read)', (tester) async {
    api.on('POST', _register, _approval());
    await _pump(tester);

    await _submit(tester, 'Continue');

    expect(find.byType(RegistrationRequestPage), findsOneWidget);
    // The server can't be read here: what the form knew is shown.
    expect(find.text("You're registered!"), findsOneWidget);
    expect(find.text('Hack Night'), findsOneWidget);
  });

  testWidgets(
      'an approval without its link (sent again from elsewhere): "You\'ve '
      'already registered", with nothing to read or cancel', (tester) async {
    api.on('POST', _register, {
      'approval': {
        'id': 'req-1',
        'status': 'pending',
        'submitted_at': '2026-10-26T09:00:00Z',
        'token': null,
        'status_url': null,
      },
      'event_registration_id': null,
      'event_id': 7,
      'event_name': 'Hack Night',
    });
    await _pump(tester, requiresApproval: true);

    await _submit(tester, 'Register');

    expect(find.text("You've already registered"), findsOneWidget);
    expect(
        find.text("We've emailed the link to your registration to "
            'asha@example.com again.'),
        findsOneWidget);
    expect(find.text('Under review'), findsOneWidget, reason: 'the chip');
    expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);
    expect(find.byKey(RegistrationRequestPage.seeKey), findsNothing);
    expect(
        api.requests.where((r) => r.path.startsWith('/registration-requests')),
        isEmpty);
  });

  testWidgets(
      'sent again for a registration the club confirmed already: the link '
      'was emailed again', (tester) async {
    api.on('POST', _register, {
      'approval': {
        'id': 'req-1',
        'status': 'approved',
        'submitted_at': '2026-10-26T09:00:00Z',
        'token': null,
        'status_url': null,
      },
      'event_registration_id': null,
      'event_id': 7,
      'event_name': 'Hack Night',
    });
    await _pump(tester, requiresApproval: true);

    await _submit(tester, 'Register');

    expect(find.text("You've already registered"), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget, reason: 'the chip');
    expect(
        find.text("We've emailed the link to your registration to "
            'asha@example.com again.'),
        findsOneWidget);
  });

  testWidgets(
      'turned on after the form loaded its shelf: ADD_ONS_NOT_ALLOWED said '
      'plainly, the picks taken off, and the form registers for review',
      (tester) async {
    api
      ..on('GET', '/events/7/store/catalog', {
        'enabled': true,
        'items': [
          {'id': 'tee', 'name': 'Hack Night tee', 'price': 399, 'variants': []},
        ],
      })
      ..on(
          'POST',
          _register,
          {
            'message': 'A request holds no add-ons.',
            'error_code': 'ADD_ONS_NOT_ALLOWED',
          },
          status: 422)
      ..on('POST', _register, _approval());
    await _pump(tester);
    expect(find.text('Hack Night tee'), findsOneWidget);

    await _submit(tester, 'Continue');
    expect(find.text('This event reviews registrations now'), findsOneWidget);
    expect(
        find.text("Add-ons can't be picked when registrations are reviewed, "
            "so they've been removed. Check your details and register "
            'again.'),
        findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Hack Night tee'), findsNothing);
    await _submit(tester, 'Register');
    final second = api.sent('POST', _register).last.data as Map;
    expect(second.containsKey('store'), isFalse);
    expect(find.byType(RegistrationRequestPage), findsOneWidget);
  });

  testWidgets('declined before: said plainly, then back to the event',
      (tester) async {
    api.on(
        'POST',
        _register,
        {
          'message': "The organisers couldn't confirm your registration "
              "for this event, so you can't register again with this email.",
          'error_code': 'REQUEST_DECLINED',
        },
        status: 409);
    final (closedWith, _) = await _pump(tester, requiresApproval: true);

    await _submit(tester, 'Register');
    expect(find.text("You can't register again"), findsOneWidget);
    expect(
        find.text("Tinkerhub couldn't confirm your registration for this "
            "event, so you can't register again with this email."),
        findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(EventFormPage), findsNothing);
    expect(closedWith, [null]);
  });

  testWidgets('APPROVAL_REQUIRED: said plainly, the form kept', (tester) async {
    api.on(
        'POST',
        _register,
        {
          'message': 'This event needs the club to confirm each place. Update '
              'the app, or register on myotherapp.in.',
          'error_code': 'APPROVAL_REQUIRED',
        },
        status: 409);
    await _pump(tester);

    await _submit(tester, 'Continue');
    expect(find.text('This event reviews registrations now'), findsOneWidget);
    expect(find.text('Register again from the event page.'), findsOneWidget);
    expect(find.textContaining('Update the app'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(EventFormPage), findsOneWidget);
  });

  testWidgets('/events/request-sent with nothing handed to it: My events',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/events/request-sent', routes: [
      GoRoute(
        path: '/events/request-sent',
        redirect: requestSentRedirect,
        builder: buildRequestSentPage,
      ),
      GoRoute(
        path: '/events',
        builder: (_, __) => const Scaffold(body: Text('My events')),
      ),
    ]);
    await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('My events'), findsOneWidget);
  });
}
