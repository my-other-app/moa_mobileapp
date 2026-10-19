import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/utils/event_calendar.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_entries.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_venue.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'event_page_fixtures.dart';
import 'events_fakes.dart';

/// What a test's page did outside itself.
class _Harness {
  final List<Uri> opened = [];
  final List<CalendarEntry> calendar = [];
  final List<(String, Object?)> went = [];
  late GoRouter router;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The event page at `/events/{ref}` inside a router whose other pages
/// record where the page sent the person.
Future<_Harness> _pump(
  WidgetTester tester, {
  String ref = '7',
  bool signedIn = true,
  bool calendarOpens = true,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final h = _Harness();
  Widget record(GoRouterState state, String label) {
    h.went.add((state.uri.toString(), state.extra));
    return Scaffold(body: Text(label));
  }

  h.router = GoRouter(initialLocation: '/events/$ref', routes: [
    GoRoute(
      path: '/events/:eventId',
      builder: (_, state) => IndividualEventPage(
        eventRef: state.pathParameters['eventId'],
        eventId: eventIdOf(state.pathParameters['eventId']!),
      ),
      routes: [
        GoRoute(
            path: 'register', builder: (_, s) => record(s, 'the form')),
        GoRoute(path: 'compete', builder: (_, s) => record(s, 'your team')),
      ],
    ),
    GoRoute(path: '/clubs/:id', builder: (_, s) => record(s, 'the club')),
    GoRoute(
        path: '/auth/onboarding', builder: (_, s) => record(s, 'sign in')),
    GoRoute(
        path: '/feedback/:e/:r', builder: (_, s) => record(s, 'the survey')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      linkLauncherProvider.overrideWithValue((uri) async {
        h.opened.add(uri);
        return true;
      }),
      calendarAdderProvider.overrideWithValue((entry) async {
        h.calendar.add(entry);
        return calendarOpens;
      }),
    ],
    child: MaterialApp.router(routerConfig: h.router),
  ));
  await _settle(tester);
  return h;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('the sections the website shows', () {
    testWidgets('from /discover/events: speakers, venue, guidelines, team, '
        'contact, seats and the rails', (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      await _pump(tester);

      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.text('ML engineer, Sarvam'), findsOneWidget);
      expect(find.text('Venue'), findsOneWidget);
      expect(find.text('Pinned on the map'), findsOneWidget);
      expect(find.byKey(EventVenueSection.mapKey), findsOneWidget);
      expect(find.text('Guidelines'), findsOneWidget);
      expect(find.text('Bring your laptop.\nNo outside food.'), findsOneWidget);
      expect(find.text('Organising team'), findsOneWidget);
      expect(find.text('Rahul Nair'), findsOneWidget);
      expect(find.text('Questions?'), findsOneWidget);
      expect(find.text('Reach Asha, who is organising this event.'),
          findsOneWidget);
      expect(find.text('hello@tinkerhub.org'), findsOneWidget);
      expect(find.text('More from Tinkerhub'), findsOneWidget);
      expect(find.text('Arduino Day'), findsOneWidget);
      expect(find.text('Similar events'), findsOneWidget);
      expect(find.text('Rust Meetup'), findsOneWidget);
      expect(find.text('1.2K followers'), findsOneWidget);

      // The seats, with the button.
      expect(find.byKey(SeatsMeter.meterKey), findsOneWidget);
      expect(find.text('82 going · 38 seats left'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'REGISTER NOW'), findsOneWidget);

      // Public, and the same for everyone: sent without the token.
      final sent = api.sent('GET', '/discover/events/7').single;
      expect(sent.extra['skipAuth'], isTrue);
    });

    testWidgets('in the website\'s order: about, speakers, agenda, venue, '
        'guidelines, team, contact, then the rails', (tester) async {
      api
        ..on('GET', '/events/info/7',
            eventInfo(extra: {'about': 'A night of building things.'}))
        ..on('GET', '/discover/events/7', discoverEventPage())
        ..on('GET', '/events/7/agenda', {
          'timezone': 'Asia/Kolkata',
          'items': [
            {
              'id': 1,
              'starts_at': '2030-12-01T10:00:00Z',
              'title': 'Doors open',
            },
          ],
        });
      await _pump(tester);

      final tops = [
        'A night of building things.',
        'Speaker',
        'Agenda',
        'Venue',
        'Guidelines',
        'Organising team',
        'Questions?',
        'More from Tinkerhub',
        'Similar events',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(tops, orderedEquals([...tops]..sort()));
    });

    testWidgets("a speaker's sheet has their bio and their link",
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      final h = await _pump(tester);

      await _tap(tester, find.text('Ananya Iyer'));
      expect(find.text('Ananya builds speech models for Indian languages.'),
          findsNWidgets(2), reason: 'the row and the sheet');
      await tester.tap(find.widgetWithText(OutlinedButton, 'LinkedIn'));
      await _settle(tester);
      expect(h.opened.single.toString(), 'https://www.linkedin.com/in/ananya');
    });

    testWidgets("a team member's sheet has their links, and no unsafe one",
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      await _pump(tester);

      await _tap(tester, find.text('Rahul Nair'));
      expect(find.widgetWithText(OutlinedButton, 'Instagram'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'X'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Website'), findsNothing);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('Directions open the maps app on ${platform.name}',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        api
          ..on('GET', '/events/info/7', eventInfo())
          ..on('GET', '/discover/events/7', discoverEventPage());
        final h = await _pump(tester);

        await _tap(tester, find.byKey(EventVenueSection.directionsKey));
        expect(
          h.opened.single.toString(),
          platform == TargetPlatform.iOS
              ? 'https://maps.apple.com/?daddr=9.9312%2C76.2673&q=CET'
              : 'https://www.google.com/maps/dir/?api=1&destination=9.9312%2C76.2673',
        );
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('a card in a rail opens that event', (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      await _pump(tester);

      api.on('GET', '/events/info/8', eventInfo(id: 8, slug: 'arduino-day'));
      await _tap(tester, find.byKey(const ValueKey('rail-event-8')));
      // Event 8's page, over this one.
      expect(api.sent('GET', '/events/info/8'), hasLength(1));
      expect(find.byType(IndividualEventPage, skipOffstage: false),
          findsNWidgets(2));

    });

    testWidgets('"See all" beside "More from" opens the club', (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      final h = await _pump(tester);

      await _tap(tester, find.widgetWithText(TextButton, 'See all'));
      expect(h.went.single.$1, '/clubs/3');
    });

    testWidgets('the contact is mailed and called from the page',
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      final h = await _pump(tester);

      await _tap(tester, find.text('hello@tinkerhub.org'));
      await _tap(tester, find.text('+91 98765 43210'));
      expect(h.opened.map((u) => u.toString()),
          ['mailto:hello@tinkerhub.org', 'tel:+919876543210']);
    });

    testWidgets(
        'a non-public event (the website API says 404) shows what '
        '/events/info has', (tester) async {
      api.on(
          'GET',
          '/events/info/7',
          eventInfo(extra: {
            'speakers': [
              {'id': 1, 'name': 'Ravi Kumar', 'designation': 'Host'},
            ],
            'event_guidelines': 'Be kind.',
            'contact_name': 'Asha',
            'contact_email': 'asha@example.com',
            'lat': 9.93,
            'lng': 76.26,
          }));
      await _pump(tester);

      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Be kind.'), findsOneWidget);
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(find.text('Pinned on the map'), findsOneWidget);
      expect(find.text('Similar events'), findsNothing);
      expect(find.byKey(SeatsMeter.meterKey), findsNothing);
      expect(find.widgetWithText(FilledButton, 'REGISTER NOW'), findsOneWidget);
    });

    testWidgets('every field missing is tolerated: no section, no crash',
        (tester) async {
      api
        ..on('GET', '/events/info/7', {'id': 7})
        ..on('GET', '/discover/events/7', {
          'event': {'id': 7},
        });
      await _pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Speaker'), findsNothing);
      expect(find.text('Guidelines'), findsNothing);
      expect(find.text('Questions?'), findsNothing);
      expect(find.text('Similar events'), findsNothing);
      expect(find.byType(IndividualEventPage), findsOneWidget);
    });

    testWidgets('an online event says the link comes with the ticket',
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo(isOnline: true))
        ..on('GET', '/discover/events/7',
            discoverEventPage(isOnline: true, lat: null, lng: null));
      await _pump(tester);

      expect(find.text('Online event'), findsOneWidget);
      expect(find.byKey(EventVenueSection.directionsKey), findsNothing);
    });
  });

  group('the register button', () {
    testWidgets('a full event: no waitlist, so the button is off',
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on(
            'GET',
            '/discover/events/7',
            discoverEventPage(
                status: 'full',
                registrationOpen: false,
                going: 120,
                seatsLeft: 0));
      await _pump(tester);

      final button = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'EVENT FULL'));
      expect(button.onPressed, isNull);
      expect(find.text('All 120 seats are taken.'), findsOneWidget);
      expect(find.byKey(SeatsMeter.meterKey), findsOneWidget);
    });

    testWidgets('few seats left is said, and still registers', (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7',
            discoverEventPage(going: 117, seatsLeft: 3));
      await _pump(tester);

      expect(find.text('Only 3 seats left'), findsOneWidget);
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'REGISTER NOW'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('not open yet says when it opens', (tester) async {
      api.on('GET', '/events/info/7',
          eventInfo(regStart: '2030-11-18T03:30:00Z'));
      await _pump(tester);

      final button = tester.widget<FilledButton>(find.byWidgetPredicate(
          (w) => w is FilledButton &&
              w.child is Text &&
              (w.child as Text).data!.startsWith('REGISTRATION OPENS')));
      expect(button.onPressed, isNull);
    });

    testWidgets('signed out, Register asks to sign in and comes back here',
        (tester) async {
      api.on('GET', '/events/info/7', eventInfo());
      final h = await _pump(tester, signedIn: false);

      await tester.tap(find.widgetWithText(FilledButton, 'REGISTER NOW'));
      await _settle(tester);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(h.went, isEmpty, reason: 'not to the form');

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await _settle(tester);
      expect(h.went.single.$1, '/auth/onboarding?from=%2Fevents%2F7');
      expect(signInLocationFrom(h.went.single.$1), '/events/7');
    });

    testWidgets('signed out, the page and its rails work as for anyone',
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', discoverEventPage());
      await _pump(tester, signedIn: false);

      expect(tester.takeException(), isNull);
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('Similar events'), findsOneWidget);
      expect(find.text('More from Tinkerhub'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'REGISTER NOW'), findsOneWidget);
    });

    testWidgets('signed out, "Not now" leaves them on the event',
        (tester) async {
      api.on('GET', '/events/info/7', eventInfo());
      final h = await _pump(tester, signedIn: false);

      await tester.tap(find.widgetWithText(FilledButton, 'REGISTER NOW'));
      await _settle(tester);
      await tester.tap(find.text('Not now'));
      await _settle(tester);
      expect(h.went, isEmpty);
      expect(find.byType(IndividualEventPage), findsOneWidget);
    });

    testWidgets('signed in, Register opens the form with the questions',
        (tester) async {
      api.on('GET', '/events/info/7', eventInfo(hasFee: true));
      final h = await _pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'REGISTER NOW'));
      await _settle(tester);
      expect(h.went.single.$1, '/events/7/register');
      final extra = h.went.single.$2 as Map;
      expect(extra['hasFee'], isTrue);
      expect(extra['isOnline'], isFalse);
    });
  });

  group('a paid online event', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('on ${platform.name}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        api.on('GET', '/events/info/7',
            eventInfo(hasFee: true, isOnline: true));
        await _pump(tester);

        if (platform == TargetPlatform.iOS) {
          expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsOneWidget);
          expect(find.text(iosOnlineSaleBlockedMessage), findsOneWidget);
          expect(find.text('REGISTER NOW'), findsNothing);
          // No way to buy it elsewhere either.
          expect(find.textContaining('website'), findsNothing);
        } else {
          expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsNothing);
          expect(find.text('REGISTER NOW'), findsOneWidget);
        }
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('awaiting payment, on ${platform.name}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        api.on(
            'GET',
            '/events/info/7',
            eventInfo(
                hasFee: true,
                isOnline: true,
                registered: true,
                isPaid: false,
                registrationId: 'reg-1'));
        await _pump(tester);

        if (platform == TargetPlatform.iOS) {
          expect(find.text(iosOnlineSaleBlockedMessage), findsOneWidget);
          expect(find.text('FINISH PAYMENT'), findsNothing);
        } else {
          expect(find.text('FINISH PAYMENT'), findsOneWidget);
        }
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('an in-person paid event is sold on iOS as before',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      api.on('GET', '/events/info/7', eventInfo(hasFee: true));
      await _pump(tester);

      expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsNothing);
      expect(find.text('REGISTER NOW'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a free online event is open on iOS as before',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      api.on('GET', '/events/info/7', eventInfo(isOnline: true));
      await _pump(tester);

      expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsNothing);
      expect(find.text('REGISTER NOW'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('Add to calendar', () {
    testWidgets('goes to the phone\'s calendar with the event filled in',
        (tester) async {
      api.on('GET', '/events/info/7', eventInfo());
      final h = await _pump(tester);

      await tester.tap(find.byTooltip('Add to calendar'));
      await _settle(tester);
      final entry = h.calendar.single;
      expect(entry.title, 'Hack Night');
      expect(entry.location, 'CET');
      expect(entry.end.difference(entry.start), const Duration(minutes: 150));
      expect(entry.description, contains('https://myotherapp.in/events/hack-night'));
      expect(h.opened, isEmpty);
    });

    testWidgets('with no calendar app, Google Calendar opens instead',
        (tester) async {
      api.on('GET', '/events/info/7', eventInfo());
      final h = await _pump(tester, calendarOpens: false);

      await tester.tap(find.byTooltip('Add to calendar'));
      await _settle(tester);
      expect(h.opened.single.host, 'calendar.google.com');
    });

    testWidgets('is not offered once the event is over', (tester) async {
      api.on('GET', '/events/info/7',
          eventInfo(start: '2020-01-01T10:00:00Z'));
      await _pump(tester);
      expect(find.byTooltip('Add to calendar'), findsNothing);
    });
  });

  group('opened by slug', () {
    testWidgets('reads the event by slug, then uses its id', (tester) async {
      api
        ..on('GET', '/events/info/hack-night', eventInfo())
        ..on('GET', '/discover/events/hack-night', discoverEventPage());
      await _pump(tester, ref: 'hack-night');

      expect(find.text('Hack Night'), findsWidgets);
      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(api.sent('GET', '/events/7/agenda'), hasLength(1));
      expect(api.sent('GET', '/events/7/live'), hasLength(1));
      expect(api.sent('GET', '/events/info/0'), isEmpty);
    });
  });

  group('your team', () {
    testWidgets('registered for an event with a competition: the way in',
        (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo(registered: true, isPaid: true))
        ..on('GET', '/events/7/competition/leaderboard',
            {'event_id': 7, 'enabled': true, 'public': false, 'rows': []});
      final h = await _pump(tester);

      await _tap(tester, find.byKey(CompetitionEntryCard.entryKey));
      expect(h.went.single.$1, '/events/7/compete');
    });

    testWidgets('no competition, no way in', (tester) async {
      api
        ..on('GET', '/events/info/7', eventInfo(registered: true, isPaid: true))
        ..on('GET', '/events/7/competition/leaderboard',
            {'event_id': 7, 'enabled': false, 'public': false, 'rows': []});
      await _pump(tester);
      expect(find.byKey(CompetitionEntryCard.entryKey), findsNothing);
    });

    testWidgets('not registered: no way in, and nothing asked',
        (tester) async {
      api.on('GET', '/events/info/7', eventInfo());
      await _pump(tester);
      expect(find.byKey(CompetitionEntryCard.entryKey), findsNothing);
      expect(api.sent('GET', '/events/7/competition/leaderboard'), isEmpty);
    });
  });

  group('the feedback survey', () {
    testWidgets('after attending, with the link: opens it here',
        (tester) async {
      api.on(
          'GET',
          '/events/info/7',
          eventInfo(
              registered: true,
              attended: true,
              start: '2020-01-01T10:00:00Z',
              extra: {
                'feedback_url':
                    'https://myotherapp.in/feedback/7/reg-1?k=abc.def',
              }));
      final h = await _pump(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Share feedback'));
      expect(h.went.single.$1, '/feedback/7/reg-1?k=abc.def');
    });

    testWidgets('after attending, without a link: where to find it',
        (tester) async {
      api.on(
          'GET',
          '/events/info/7',
          eventInfo(
              registered: true,
              attended: true,
              start: '2020-01-01T10:00:00Z'));
      await _pump(tester);

      expect(find.byKey(FeedbackEntryCard.entryKey), findsOneWidget);
      expect(find.textContaining('by email after the event'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Share feedback'), findsNothing);
    });

    testWidgets('not attended: no survey', (tester) async {
      api.on('GET', '/events/info/7', eventInfo());
      await _pump(tester);
      expect(find.byKey(FeedbackEntryCard.entryKey), findsNothing);
    });
  });
}

/// The `from` a sign-in location carries.
String? signInLocationFrom(String location) =>
    Uri.parse(location).queryParameters['from'];
