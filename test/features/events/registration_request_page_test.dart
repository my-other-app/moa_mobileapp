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
      path: '/discover/events',
      builder: (_, __) => const Scaffold(body: Text('Find events')),
    ),
    GoRoute(
      path: '/events',
      builder: (_, __) => const Scaffold(body: Text('My events')),
      routes: [
        GoRoute(
          path: ':ref',
          builder: (_, state) =>
              Scaffold(body: Text('Event ${state.pathParameters['ref']}')),
          routes: [
            GoRoute(
              path: 'register',
              builder: (_, state) => Scaffold(
                  body: Text('Register ${state.pathParameters['ref']}')),
            ),
          ],
        ),
      ],
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

/// The status chip's word, over the title; null without one.
String? _chip(WidgetTester tester) {
  final chip = find.byKey(RegistrationRequestPage.chipKey);
  if (chip.evaluate().isEmpty) return null;
  return tester
      .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .data;
}

/// The label of the button at [key].
String _label(WidgetTester tester, Key key) => tester
    .widget<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)))
    .data!;

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('under review', () {
    testWidgets('its chip, title and words, with the club and name',
        (tester) async {
      api.on('GET', _path, requestBody());
      await _pump(tester);

      expect(find.text('Your registration'), findsOneWidget,
          reason: 'the app bar');
      expect(_chip(tester), 'Under review');
      expect(_title(tester), 'Your registration is under review');
      expect(
          find.text("Asha, you're registered for Hack Night. Tinkerhub "
              'reviews every registration. If yours is confirmed, your '
              "ticket will come by email. There's nothing else to do."),
          findsOneWidget);
      expect(find.text('Hack Night'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('For Asha Menon'), findsOneWidget);
      expect(find.textContaining('Registered '), findsOneWidget);
      expect(find.textContaining('Asked '), findsNothing);
      expect(_label(tester, RegistrationRequestPage.eventKey),
          'Back to the event');
      expect(_label(tester, RegistrationRequestPage.withdrawKey),
          'Cancel my registration');
      expect(find.byKey(RegistrationRequestPage.payKey), findsNothing);
      // Read with the token alone: no session goes.
      expect(api.sent('GET', _path).single.extra['skipAuth'], isTrue);
    });

    testWidgets('cancelling asks first; "Keep my registration" does nothing',
        (tester) async {
      api.on('GET', _path, requestBody());
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      expect(find.text('Cancel your registration?'), findsOneWidget);
      expect(
          find.text("Tinkerhub won't review it any more. You can register "
              'again while registration is open.'),
          findsOneWidget);
      expect(find.text('Yes, cancel it'), findsOneWidget);
      await tester.tap(find.text('Keep my registration'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', _withdrawPath), isEmpty);
      expect(_title(tester), 'Your registration is under review');
    });

    testWidgets(
        'cancelled: says so, offers "Register again", and no more '
        'cancelling', (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('POST', _withdrawPath, requestBody(status: 'withdrawn'));
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, cancel it'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', _withdrawPath), hasLength(1));
      expect(_chip(tester), 'Cancelled');
      expect(_title(tester), 'You cancelled your registration');
      expect(
          find.text("Tinkerhub won't review it any more. If you change your "
              'mind, you can register again while registration is open.'),
          findsOneWidget);
      expect(find.text('Your registration was cancelled.'), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);

      await tester.tap(find.byKey(RegistrationRequestPage.registerAgainKey));
      await tester.pumpAndSettle();
      expect(find.text('Register hack-night'), findsOneWidget);
    });

    testWidgets('the email\'s "Cancel my registration" asks at once',
        (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('POST', _withdrawPath, requestBody(status: 'withdrawn'));
      await _pump(tester, location: '/requests/tok_1?withdraw=1');

      expect(find.text('Cancel your registration?'), findsOneWidget);
      await tester.tap(find.text('Yes, cancel it'));
      await tester.pumpAndSettle();
      expect(_title(tester), 'You cancelled your registration');
    });

    testWidgets('... and asks nothing of a registration already decided',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'declined'));
      await _pump(tester, location: '/requests/tok_1?withdraw=1');

      expect(find.text('Cancel your registration?'), findsNothing);
      expect(_title(tester), "Your registration wasn't confirmed");
    });

    testWidgets(
        "it can't be cancelled any more: \"changed meanwhile\", over the "
        'registration as it stands, from the refusal', (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on(
            'POST',
            _withdrawPath,
            {
              'message': "This registration can't be cancelled any more.",
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
      await tester.tap(find.text('Yes, cancel it'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', _path), hasLength(1),
          reason: 'the refusal said how it stands');
      expect(_title(tester), 'Your registration is confirmed');
      expect(find.text('Pay ₹299'), findsOneWidget);
      expect(
          find.text(RegistrationRequestPage.changedMeanwhile), findsOneWidget);
      expect(
          find.text(
              "Your registration changed meanwhile, so it wasn't cancelled. "
              "Here's where it stands now."),
          findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.problemKey), findsNothing);
    });

    testWidgets(
        'cancelling one decided meanwhile (another refusal): read again, '
        'and "changed meanwhile"', (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('GET', _path, requestBody(status: 'declined'))
        ..on('POST', _withdrawPath,
            {'message': 'No longer open.', 'error_code': 'REQUEST_CLOSED'},
            status: 409);
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, cancel it'));
      await tester.pumpAndSettle();

      expect(_title(tester), "Your registration wasn't confirmed");
      expect(find.byKey(RegistrationRequestPage.noticeKey), findsOneWidget);
    });

    testWidgets("a failure: \"We couldn't cancel your registration\"",
        (tester) async {
      api
        ..on('GET', _path, requestBody())
        ..on('POST', _withdrawPath, {'message': 'Boom'}, status: 500);
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, cancel it'));
      await tester.pumpAndSettle();

      expect(find.byKey(RegistrationRequestPage.problemKey), findsOneWidget);
      expect(find.text("We couldn't cancel your registration"), findsOneWidget);
      expect(_title(tester), 'Your registration is under review');
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsOneWidget);
    });

    const initial = RegistrationRequest(
      id: 'req-1',
      status: RequestStatus.pending,
      token: 'tok_1',
      event: RequestEvent(id: 7, name: 'Hack Night', clubName: 'Tinkerhub'),
    );

    testWidgets(
        'what the opener knew stays when the server can\'t be read; no '
        'name: "You\'re registered for…"', (tester) async {
      api.on('GET', _path, {'message': 'Boom'}, status: 503);
      await _pump(tester, initial: initial);

      expect(_title(tester), 'Your registration is under review');
      expect(
          find.text("You're registered for Hack Night. Tinkerhub reviews "
              'every registration. If yours is confirmed, your ticket will '
              "come by email. There's nothing else to do."),
          findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.retryKey), findsNothing);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsOneWidget);
    });

    testWidgets('what the opener knew gives way to the server\'s word',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'declined'));
      await _pump(tester, initial: initial);

      expect(_title(tester), "Your registration wasn't confirmed");
    });
  });

  group('confirmed', () {
    testWidgets('with its ticket: straight on to the ticket', (tester) async {
      api.on('GET', _path, requestBody(status: 'approved', ticketId: 'T-9'));
      await _pump(tester);

      expect(find.text('Ticket T-9'), findsOneWidget);
      expect(find.byType(RegistrationRequestPage), findsNothing,
          reason: 'the ticket took its place');
      // Back goes where it would have from the registration.
      final router = GoRouter.of(tester.element(find.text('Ticket T-9')));
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('with its ticket, before it hands over: "You\'re in"',
        (tester) async {
      api.on('GET', _path, {'message': 'Boom'}, status: 503);
      await _pump(tester,
          initial: const RegistrationRequest(
            id: 'req-1',
            status: RequestStatus.approved,
            token: 'tok_1',
            ticketId: 'T-9',
            event:
                RequestEvent(id: 7, name: 'Hack Night', clubName: 'Tinkerhub'),
          ));

      expect(_chip(tester), 'Confirmed');
      expect(_title(tester), "You're in");
      expect(
          find.text('Tinkerhub confirmed your registration for Hack Night. '
              'Your ticket is in your email too.'),
          findsOneWidget);
      expect(_label(tester, RegistrationRequestPage.ticketKey),
          'View your ticket');
      expect(_label(tester, RegistrationRequestPage.eventKey),
          'Back to the event');
    });

    testWidgets('to pay: "Pay ₹X by {time}", which opens the claim screen',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'approved', pay: payBody()));
      await _pump(tester);

      expect(_chip(tester), startsWith('Confirmed · pay by '));
      expect(_chip(tester), endsWith(' to get your ticket'));
      expect(_title(tester), 'Your registration is confirmed');
      expect(find.textContaining('Pay ₹199 by '), findsOneWidget);
      expect(
          find.textContaining(' to get your ticket for Hack Night. Your '
              'ticket is held for you until then.'),
          findsOneWidget);
      expect(find.text('Pay ₹199'), findsOneWidget);
      expect(find.text("I can't come: cancel my registration"), findsOneWidget);

      await tester.tap(find.byKey(RegistrationRequestPage.payKey));
      await tester.pumpAndSettle();
      expect(find.text('Claim clm_1'), findsOneWidget);
    });

    testWidgets('cancelling it says the ticket goes to someone else',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'approved', pay: payBody()));
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.withdrawKey));
      await tester.pumpAndSettle();
      expect(find.text('Cancel your registration?'), findsOneWidget);
      expect(
          find.text("Your ticket will go to someone else, and you can't undo "
              'this.'),
          findsOneWidget);
    });

    testWidgets(
        'paid there: back on the registration, it reads again and goes on '
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

    testWidgets('neither a ticket nor a pay link: look in your email',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'approved'));
      await _pump(tester);

      expect(_chip(tester), 'Confirmed');
      expect(_title(tester), 'Your registration is confirmed');
      expect(
          find.text('Look in your email for your ticket, or for the link to '
              'pay for it.'),
          findsOneWidget);
      expect(
          _label(tester, RegistrationRequestPage.myTicketsKey), 'My tickets');
      await tester.tap(find.byKey(RegistrationRequestPage.myTicketsKey));
      await tester.pumpAndSettle();
      expect(find.text('My events'), findsOneWidget);
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

      expect(_title(tester), 'Your registration is confirmed');
      expect(find.textContaining('₹'), findsNothing);
      expect(find.byKey(RegistrationRequestPage.payKey), findsNothing);
      expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsOneWidget);
      expect(
          find.textContaining('Your ticket for Hack Night is held for you '
              'until '),
          findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('settled', () {
    testWidgets('not confirmed, with the club\'s note', (tester) async {
      api.on('GET', _path,
          requestBody(status: 'declined', declineNote: 'We ran out of room.'));
      await _pump(tester);

      expect(_chip(tester), 'Not confirmed');
      expect(_title(tester), "Your registration wasn't confirmed");
      expect(
          find.text('Thank you for your interest in Hack Night. Tinkerhub '
              "couldn't confirm your registration this time."),
          findsOneWidget);
      expect(find.text('Tinkerhub said: We ran out of room.'), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);
      expect(_label(tester, RegistrationRequestPage.findEventsKey),
          'Find other events');

      await tester.tap(find.byKey(RegistrationRequestPage.eventKey));
      await tester.pumpAndSettle();
      expect(find.text('Event hack-night'), findsOneWidget);
    });

    testWidgets('"Find other events" finds them', (tester) async {
      api.on('GET', _path, requestBody(status: 'declined'));
      await _pump(tester);

      await tester.tap(find.byKey(RegistrationRequestPage.findEventsKey));
      await tester.pumpAndSettle();
      expect(find.text('Find events'), findsOneWidget);
    });

    testWidgets('cancelled', (tester) async {
      api.on('GET', _path, requestBody(status: 'withdrawn'));
      await _pump(tester);
      expect(_chip(tester), 'Cancelled');
      expect(_title(tester), 'You cancelled your registration');
      expect(_label(tester, RegistrationRequestPage.registerAgainKey),
          'Register again');
      expect(find.byKey(RegistrationRequestPage.withdrawKey), findsNothing);
    });

    testWidgets('expired', (tester) async {
      api.on('GET', _path, requestBody(status: 'lapsed'));
      await _pump(tester);
      expect(_chip(tester), 'Expired');
      expect(_title(tester), 'Your registration has expired');
      expect(
          find.text('Tinkerhub confirmed your registration for Hack Night, '
              "but it wasn't paid in time. If registration is still open, "
              'you can register again.'),
          findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.eventKey), findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.findEventsKey), findsOneWidget);
    });

    group('closed, by its reason', () {
      for (final reason in [null, 'event_ended', 'event_deleted']) {
        testWidgets(
            '${reason ?? 'no reason'}: ended before the club could '
            'confirm it', (tester) async {
          api.on('GET', _path,
              requestBody(status: 'closed', closedReason: reason));
          await _pump(tester);
          expect(_chip(tester), 'Closed');
          expect(_title(tester), 'This registration is closed');
          expect(
              find.text('Hack Night ended before Tinkerhub could confirm your '
                  'registration.'),
              findsOneWidget);
          expect(find.byKey(RegistrationRequestPage.eventKey), findsOneWidget);
          expect(find.byKey(RegistrationRequestPage.findEventsKey),
              findsOneWidget);
        });
      }

      testWidgets('event_cancelled: the event was cancelled', (tester) async {
        api.on('GET', _path,
            requestBody(status: 'closed', closedReason: 'event_cancelled'));
        await _pump(tester);
        expect(_chip(tester), 'Closed');
        expect(_title(tester), 'This registration is closed');
        expect(
            find.text("Hack Night was cancelled. We've emailed you about it."),
            findsOneWidget);
      });

      testWidgets('registered_directly: they have a ticket already',
          (tester) async {
        api.on('GET', _path,
            requestBody(status: 'closed', closedReason: 'registered_directly'));
        await _pump(tester);
        expect(_title(tester), "You're registered");
        expect(find.text('You have a ticket for Hack Night already.'),
            findsOneWidget);
        expect(
            _label(tester, RegistrationRequestPage.myTicketsKey), 'My tickets');
        expect(find.byKey(RegistrationRequestPage.eventKey), findsOneWidget);
      });

      testWidgets('without the event\'s name: "The event ended…", "the club"',
          (tester) async {
        api.on('GET', _path, {
          ...requestBody(status: 'closed', closedReason: 'event_ended'),
          'event': null,
        });
        await _pump(tester);
        expect(
            find.text('The event ended before the club could confirm your '
                'registration.'),
            findsOneWidget);
      });
    });

    testWidgets('a word this build doesn\'t know: check your email',
        (tester) async {
      api.on('GET', _path, requestBody(status: 'archived'));
      await _pump(tester);
      expect(_chip(tester), isNull);
      expect(_title(tester), 'Your registration');
      expect(
          find.text('Check your email for the latest from Tinkerhub about '
              'your registration.'),
          findsOneWidget);
      expect(find.byKey(RegistrationRequestPage.eventKey), findsOneWidget);
    });
  });

  group('no answer', () {
    testWidgets('an unknown token: the link isn\'t valid', (tester) async {
      await _pump(tester);
      expect(_title(tester), "This link isn't valid");
      expect(
          find.text("We couldn't find a registration at this address. Check "
              'that the whole link was copied from your email: each link '
              'shows one registration.'),
          findsOneWidget);
    });

    testWidgets('too many reads: said plainly', (tester) async {
      api.on('GET', _path, {'message': 'Rate limit exceeded'}, status: 429);
      await _pump(tester);

      expect(_title(tester), "Your registration didn't load");
      expect(find.text('Too many tries. Wait a minute, then try again.'),
          findsOneWidget);
    });

    testWidgets('a failure, then Try again', (tester) async {
      api
        ..on('GET', _path, {'message': 'Boom'}, status: 500)
        ..on('GET', _path, requestBody());
      await _pump(tester);

      expect(_title(tester), "Your registration didn't load");
      expect(
          find.text("We couldn't reach MyOtherApp to read this registration. "
              'Check your connection and try again.'),
          findsOneWidget);
      await tester.tap(find.byKey(RegistrationRequestPage.retryKey));
      await tester.pumpAndSettle();
      expect(_title(tester), 'Your registration is under review');
    });
  });
}
