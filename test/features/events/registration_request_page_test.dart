import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/pages/registration_request_page.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';
import 'registration_approval_model_test.dart' show requestBody, payBody;

const _path = '/registration-requests/tok_1';
const _withdrawPath = '/registration-requests/tok_1/withdraw';

/// The status screen at [location], with the screens it hands over to.
Future<void> _pump(
  WidgetTester tester, {
  String location = '/requests/tok_1',
  RegistrationRequest? initial,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.push(location,
                extra: initial == null ? null : {'request': initial}),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/requests/:token',
      builder: (_, state) => RegistrationRequestPage(
        token: state.pathParameters['token']!,
        initial: (state.extra as Map?)?['request'] as RegistrationRequest?,
        openPay: state.uri.queryParameters['next'] == 'pay',
        askWithdraw: state.uri.queryParameters['withdraw'] == '1',
      ),
    ),
    GoRoute(
      path: '/claim/:token',
      builder: (_, state) =>
          Scaffold(body: Text('Claim ${state.pathParameters['token']}')),
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
      isAuthenticatedProvider.overrideWithValue(true),
      savedTicketsRepositoryProvider.overrideWithValue(SavedTicketsRepository(
        dio: APIService.instance.dio,
        local: SavedTicketsLocalDataSource(MemoryStorage()),
      )),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(RegistrationRequestPage.titleKey)).data!;

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('pending', () {
    testWidgets('on the waiting list, with the club named', (tester) async {
      api.on('GET', _path, requestBody());
      await _pump(tester);

      expect(_title(tester), "You're on the waiting list");
      expect(
          find.text('Tinkerhub confirms each registration. We\'ll notify you '
              'and email your ticket as soon as they confirm your place.'),
          findsOneWidget);
      expect(find.text('Hack Night'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('For Asha Menon'), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.payKey), findsNothing);
      // Read with the token alone: no session goes.
      expect(api.sent('GET', _path).single.extra['skipAuth'], isTrue);
    });

    testWidgets('withdraw asks first; "Keep it" does nothing', (tester) async {
      api.on('GET', _path, requestBody());
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw your request?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', _withdrawPath), isEmpty);
      expect(_title(tester), "You're on the waiting list");
    });

    testWidgets('withdrawn once confirmed: says so, and no more Withdraw',
        (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('POST', _withdrawPath, requestBody(status: 'withdrawn'));
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', _withdrawPath), hasLength(1));
      expect(_title(tester), 'You withdrew your request');
      expect(find.text('Your request was withdrawn.'), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);
    });

    testWidgets('the email\'s "Withdraw your request" asks at once',
        (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('POST', _withdrawPath, requestBody(status: 'withdrawn'));
      await _pump(tester, location: '/requests/tok_1?withdraw=1');

      expect(find.text('Withdraw your request?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();
      expect(_title(tester), 'You withdrew your request');
    });

    testWidgets('... and asks nothing of a request already decided',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'declined'));
      await _pump(tester, location: '/requests/tok_1?withdraw=1');

      expect(find.text('Withdraw your request?'), findsNothing);
      expect(_title(tester), "Tinkerhub couldn't offer you a place");
    });

    testWidgets(
        'not withdrawable any more: the request as it stands, from the '
        'refusal', (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on(
            'POST',
            _withdrawPath,
            {
              'message': 'This request can no longer be withdrawn.',
              'error_code': 'REQUEST_NOT_WITHDRAWABLE',
              'errors': {
                'request':
                    requestBody(status: 'approved', pay: payBody(amount: 299)),
              },
            },
            status: 409);
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', _path), hasLength(1),
          reason: 'the refusal said how it stands');
      expect(_title(tester), 'Tinkerhub confirmed your place');
      expect(find.text('PAY ₹299'), findsOneWidget);
      expect(find.text('This request can no longer be withdrawn.'),
          findsOneWidget);
    });

    testWidgets('withdrawing a request decided meanwhile shows what it is now',
        (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('GET', _path, requestBody(status: 'declined'))
        ..on(
            'POST',
            _withdrawPath,
            {
              'message': 'This request can no longer be withdrawn.',
              'error_code': 'REQUEST_CLOSED'
            },
            status: 409);
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      expect(_title(tester), "Tinkerhub couldn't offer you a place");
      expect(find.byKey(RegistrationRequestPage.problemKey), findsOneWidget);
    });

    const initial = RegistrationRequest(
      id: 'req-1',
      status: RequestStatus.pending,
      token: 'tok_1',
      event: RequestEvent(id: 7, name: 'Hack Night', clubName: 'Tinkerhub'),
    );

    testWidgets('what the opener knew stays when the server can\'t be read',
        (tester) async {
      api.on('GET', _path, {'message': 'Boom'}, status: 503);
      await _pump(tester, initial: initial);

      expect(_title(tester), "You're on the waiting list");
      expect(find.byKey(RegistrationRequestPage.retryKey), findsNothing);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsOneWidget);
    });

    testWidgets('what the opener knew gives way to the server\'s word',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'declined'));
      await _pump(tester, initial: initial);

      expect(_title(tester), "Tinkerhub couldn't offer you a place");
    });
  });

  group('confirmed', () {
    testWidgets('with its ticket: straight on to the ticket', (tester) async {
      api.on('GET', _path, requestBody(status: 'approved', ticketId: 'T-9'));
      await _pump(tester);

      expect(find.text('Ticket T-9'), findsOneWidget);
      expect(find.byType(RegistrationRequestPage), findsNothing,
          reason: 'the ticket took its place');
      // Back goes where it would have from the request.
      final router = GoRouter.of(tester.element(find.text('Ticket T-9')));
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('to pay: "Pay ₹X by {time}", which opens the claim screen',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'approved', pay: payBody()));
      await _pump(tester);

      expect(_title(tester), 'Tinkerhub confirmed your place');
      expect(find.textContaining('Pay ₹199 by '), findsOneWidget);
      expect(find.textContaining('to get your ticket.'), findsOneWidget);
      expect(find.text('PAY ₹199'), findsOneWidget);
      expect(find.text("I can't make it, give up my place"), findsOneWidget);

      await tester.tap(find.byKey(RegistrationRequestPage.payKey));
      await tester.pumpAndSettle();
      expect(find.text('Claim clm_1'), findsOneWidget);
    });

    testWidgets(
        'paid there: back on the request, it reads again and goes on '
        'to the ticket', (tester) async {
      api
        ..on('GET', _path, requestBody(status: 'approved', pay: payBody()))
        ..on('GET', _path, requestBody(status: 'approved', ticketId: 'T-9'));
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.payKey));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.text('Claim clm_1')));
      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Ticket T-9'), findsOneWidget);
    });

    testWidgets('the "pay" push goes straight on to the claim screen',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'approved', pay: payBody()));
      await _pump(tester, location: '/requests/tok_1?next=pay');

      expect(find.text('Claim clm_1'), findsOneWidget);
    });

    testWidgets('the "pay" push whose token is the claim link\'s own',
        (tester) async {
      await _pump(tester, location: '/requests/clm_2?next=pay');
      expect(find.text('Claim clm_2'), findsOneWidget);
    });

    testWidgets('on an iPhone, a paid online event: no price and no button',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      api
        ..on('GET', _path, requestBody(status: 'approved', pay: payBody()))
        ..on('GET', '/discover/events/hack-night', {
          'event': {'id': 7, 'slug': 'hack-night', 'is_online': true},
        });
      await _pump(tester);

      expect(_title(tester), 'Tinkerhub confirmed your place');
      expect(find.textContaining('₹'), findsNothing);
      expect(find.byKey(RegistrationRequestPage.payKey), findsNothing);
      expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('settled', () {
    testWidgets('declined, with the club\'s note', (tester) async {
      api.on('GET', _path,
          requestBody(status: 'declined', declineNote: 'We ran out of room.'));
      await _pump(tester);

      expect(_title(tester), "Tinkerhub couldn't offer you a place");
      expect(
          find.text("Sorry, Tinkerhub couldn't offer you a place at Hack "
              'Night this time.'),
          findsOneWidget);
      expect(find.text('Tinkerhub said: We ran out of room.'), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);

      await tester.tap(find.byKey(RegistrationRequestPage.eventKey));
      await tester.pumpAndSettle();
      expect(find.text('Event hack-night'), findsOneWidget);
    });

    testWidgets('withdrawn', (tester) async {
      api.on('GET', _path, requestBody(status: 'withdrawn'));
      await _pump(tester);
      expect(_title(tester), 'You withdrew your request');
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);
    });

    testWidgets('lapsed', (tester) async {
      api.on('GET', _path, requestBody(status: 'lapsed'));
      await _pump(tester);
      expect(_title(tester), 'Your place was released');
      expect(find.textContaining("the payment didn't arrive in time"),
          findsOneWidget);
    });

    testWidgets('closed', (tester) async {
      api.on('GET', _path, requestBody(status: 'closed'));
      await _pump(tester);
      expect(_title(tester), 'This request is closed');
      expect(
          find.text('Hack Night is over or was cancelled, so its requests '
              'are closed.'),
          findsOneWidget);
    });

    testWidgets('a word this build doesn\'t know: the event', (tester) async {
      api.on('GET', _path, requestBody(status: 'archived'));
      await _pump(tester);
      expect(_title(tester), "We can't show this request");
      expect(find.byKey(RegistrationRequestPage.eventKey), findsOneWidget);
    });
  });

  group('no answer', () {
    testWidgets('an unknown token: the link isn\'t valid', (tester) async {
      await _pump(tester);
      expect(_title(tester), "This link isn't valid");
    });

    testWidgets('too many reads: said plainly', (tester) async {
      api.on('GET', _path, {'message': 'Rate limit exceeded'}, status: 429);
      await _pump(tester);

      expect(_title(tester), "We couldn't open your request");
      expect(find.text('Too many tries. Wait a minute, then try again.'),
          findsOneWidget);
    });

    testWidgets('a failure, then Try again', (tester) async {
      api
        ..on('GET', _path, {'message': 'Boom'}, status: 500)
        ..on('GET', _path, requestBody());
      await _pump(tester);

      expect(_title(tester), "We couldn't open your request");
      await tester.tap(find.byKey(RegistrationRequestPage.retryKey));
      await tester.pumpAndSettle();
      expect(_title(tester), "You're on the waiting list");
    });
  });
}
