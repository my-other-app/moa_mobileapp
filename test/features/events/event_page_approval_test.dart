import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';
import 'registration_approval_model_test.dart' show requestBody, payBody;
import 'ticketing_model_test.dart' show ticketingBody;

const _info = '/events/info/7';
const _mine = '/registration-requests/mine';

Map<String, dynamic> _event({
  bool? requiresApproval,
  Map<String, dynamic>? ticketing,
  bool registered = false,
}) =>
    {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': false,
      'reg_fee': 0,
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
      'is_paid': registered ? true : null,
      if (requiresApproval != null) 'requires_approval': requiresApproval,
      if (ticketing != null) 'ticketing': ticketing,
    };

Future<void> _pump(WidgetTester tester, {bool signedIn = true}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const IndividualEventPage(eventId: 7),
    ),
    GoRoute(
      path: '/requests/:token',
      builder: (_, state) =>
          Scaffold(body: Text('Request ${state.pathParameters['token']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(signedIn),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _note = 'Tinkerhub reviews every registration and emails tickets to '
    'the people it confirms.';

const _underReview = 'Tinkerhub reviews every registration. If yours is '
    'confirmed, your ticket will come by email.';

/// "Pay ₹199 by {time} to get your ticket.", for [payBody]'s time.
String _payBy() {
  final by = RegistrationRequest.fromJson(
          requestBody(status: 'approved', pay: payBody()))!
      .pay!
      .payBy!;
  return 'Pay ₹199 by ${requestMoment(by)} to get your ticket.';
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets(
      'the club reviews every registration: "Register", as on any event, '
      'and the note', (tester) async {
    api.on('GET', _info, _event(requiresApproval: true));
    await _pump(tester);

    expect(find.text('REGISTER NOW'), findsOneWidget);
    expect(find.text('REQUEST A PLACE'), findsNothing);
    expect(find.byKey(IndividualEventPage.approvalNoteKey), findsOneWidget);
    expect(find.byKey(IndividualEventPage.approvalTitleKey), findsNothing);
    expect(find.text(_note), findsOneWidget);
    expect(find.textContaining('confirms each place'), findsNothing);
  });

  testWidgets('said by the ticket types instead', (tester) async {
    api.on(
        'GET',
        _info,
        _event(ticketing: {
          ...ticketingBody(requiresChoice: false, types: [
            {'id': 1, 'name': 'General', 'price': 0, 'status': 'on_sale'},
          ]),
          'requires_approval': true,
        }));
    await _pump(tester);
    expect(find.text('REGISTER NOW'), findsOneWidget);
    expect(find.text(_note), findsOneWidget);
  });

  testWidgets('without requires_approval: as it was', (tester) async {
    api.on('GET', _info, _event());
    await _pump(tester);

    expect(find.text('REGISTER NOW'), findsOneWidget);
    expect(find.text('REQUEST A PLACE'), findsNothing);
    expect(find.byKey(IndividualEventPage.approvalNoteKey), findsNothing);
    expect(api.sent('GET', _mine), isEmpty,
        reason: 'no requests are asked for an event that takes none');
  });

  testWidgets('requires_approval false: as it was', (tester) async {
    api.on('GET', _info, _event(requiresApproval: false));
    await _pump(tester);
    expect(find.text('REGISTER NOW'), findsOneWidget);
    expect(find.byKey(IndividualEventPage.approvalNoteKey), findsNothing);
  });

  testWidgets('registered already, under review: the button opens it',
      (tester) async {
    api
      ..on('GET', _info, _event(requiresApproval: true))
      ..on('GET', _mine, {
        'items': [requestBody(token: 'tok_1')]
      });
    await _pump(tester);

    expect(find.text('Your registration is under review'), findsOneWidget);
    expect(find.text(_underReview), findsOneWidget);
    expect(find.text('SEE YOUR REGISTRATION'), findsOneWidget);
    await tester.tap(find.text('SEE YOUR REGISTRATION'));
    await tester.pumpAndSettle();
    expect(find.text('Request tok_1'), findsOneWidget);
  });

  testWidgets('confirmed and waiting for the payment: the button opens it',
      (tester) async {
    api
      ..on('GET', _info, _event(requiresApproval: true))
      ..on('GET', _mine, {
        'items': [
          requestBody(token: 'tok_1', status: 'approved', pay: payBody())
        ]
      });
    await _pump(tester);

    expect(find.text('Your registration is confirmed'), findsOneWidget);
    expect(find.text(_payBy()), findsOneWidget);
    expect(find.text('PAY ₹199'), findsOneWidget);
    await tester.tap(find.text('PAY ₹199'));
    await tester.pumpAndSettle();
    expect(find.text('Request tok_1'), findsOneWidget);
  });

  group('the event\'s own viewer_request', () {
    Map<String, dynamic> withViewer(Map<String, dynamic>? request) =>
        _event(ticketing: {
          ...ticketingBody(requiresChoice: false, types: [
            {'id': 1, 'name': 'General', 'price': 0, 'status': 'on_sale'},
          ]),
          'requires_approval': true,
          'viewer_request': request,
        });

    testWidgets(
        'under review: "Your registration is under review", which '
        'opens it', (tester) async {
      api.on(
          'GET',
          _info,
          withViewer({
            'id': 'req-1',
            'status': 'pending',
            'token': 'tok_9',
            'status_url': 'https://myotherapp.in/requests/tok_9',
          }));
      await _pump(tester);

      expect(find.text('Your registration is under review'), findsOneWidget);
      expect(find.text(_underReview), findsOneWidget);
      expect(find.text('SEE YOUR REGISTRATION'), findsOneWidget);
      expect(find.text('REGISTER NOW'), findsNothing);
      expect(api.sent('GET', _mine), isEmpty,
          reason: 'the event said it; My events\' list is not asked');

      await tester.tap(find.text('SEE YOUR REGISTRATION'));
      await tester.pumpAndSettle();
      expect(find.text('Request tok_9'), findsOneWidget);
    });

    testWidgets(
        'confirmed and unpaid, with no amount said: "Pay now", and it '
        'opens the registration', (tester) async {
      api.on(
          'GET',
          _info,
          withViewer({
            'id': 'req-1',
            'status': 'approved',
            'token': 'tok_9',
            'status_url': 'https://myotherapp.in/requests/tok_9',
          }));
      await _pump(tester);

      expect(find.text('Your registration is confirmed'), findsOneWidget);
      expect(find.text('Pay to get your ticket.'), findsOneWidget);
      expect(find.text('PAY NOW'), findsOneWidget);
      await tester.tap(find.text('PAY NOW'));
      await tester.pumpAndSettle();
      expect(find.text('Request tok_9'), findsOneWidget);
    });

    testWidgets('without its link: "Under review", and the form isn\'t offered',
        (tester) async {
      api.on(
          'GET',
          _info,
          withViewer({
            'id': 'req-1',
            'status': 'pending',
            'token': null,
            'status_url': null,
          }));
      await _pump(tester);

      expect(find.text('Your registration is under review'), findsOneWidget);
      expect(find.text('UNDER REVIEW'), findsOneWidget);
      expect(find.text('REGISTER NOW'), findsNothing);
      final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('event-register-button')));
      expect(button.onPressed, isNull);
    });

    testWidgets('a declined one: register as before', (tester) async {
      api.on(
          'GET',
          _info,
          withViewer({
            'id': 'req-1',
            'status': 'declined',
            'token': 'tok_9',
          }));
      await _pump(tester);
      expect(find.text('REGISTER NOW'), findsOneWidget);
      expect(find.text(_note), findsOneWidget);
    });

    testWidgets('null: register, and nothing else is asked', (tester) async {
      api.on('GET', _info, withViewer(null));
      await _pump(tester);

      expect(find.text('REGISTER NOW'), findsOneWidget);
      expect(api.sent('GET', _mine), isEmpty);
    });
  });

  testWidgets('a registration for another event, or a settled one: register',
      (tester) async {
    api
      ..on('GET', _info, _event(requiresApproval: true))
      ..on('GET', _mine, {
        'items': [
          requestBody(token: 'tok_x', eventId: 99),
          requestBody(token: 'tok_w', status: 'withdrawn'),
        ]
      });
    await _pump(tester);
    expect(find.text('REGISTER NOW'), findsOneWidget);
    expect(find.text('Your registration is under review'), findsNothing);
  });

  testWidgets('signed out: registers, and reads no registrations',
      (tester) async {
    api.on('GET', _info, _event(requiresApproval: true));
    await _pump(tester, signedIn: false);
    expect(find.text('REGISTER NOW'), findsOneWidget);
    expect(find.text(_note), findsOneWidget);
    expect(api.sent('GET', _mine), isEmpty);
  });

  testWidgets('registered already: the ticket, no note', (tester) async {
    api.on('GET', _info, _event(requiresApproval: true, registered: true));
    await _pump(tester);
    expect(find.text('REGISTER NOW'), findsNothing);
    expect(find.byKey(IndividualEventPage.approvalNoteKey), findsNothing);
  });
}
