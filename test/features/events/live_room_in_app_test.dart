import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/push_dedupe.dart';
import 'package:finnet/features/auth/presentation/pages/splash_screen.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'events_fakes.dart';

/// The push the backend sends when a host starts a quiz or a poll.
const _quizPush = {
  'type': 'event_live_join',
  'event_id': '68',
  'what': 'quiz',
  'push_id': '0b5f3c1e-0000-4000-8000-000000000001',
};

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  group('openInAppThenBrowser', () {
    final room = Uri.parse('https://myotherapp.in/68/live');

    test('opens inside the app when it can', () async {
      final modes = <LaunchMode>[];
      final opened = await openInAppThenBrowser(room, launch: (uri, mode) async {
        modes.add(mode);
        return true;
      });

      expect(opened, isTrue);
      expect(modes, [LaunchMode.inAppBrowserView]);
    });

    test('falls back to the browser when the in-app view says no', () async {
      final modes = <LaunchMode>[];
      final opened = await openInAppThenBrowser(room, launch: (uri, mode) async {
        modes.add(mode);
        return mode == LaunchMode.externalApplication;
      });

      expect(opened, isTrue);
      expect(modes, [LaunchMode.inAppBrowserView, LaunchMode.externalApplication]);
    });

    test('or throws, and answers false when nothing can open it', () async {
      final modes = <LaunchMode>[];
      final fallback = await openInAppThenBrowser(room, launch: (uri, mode) async {
        modes.add(mode);
        if (mode == LaunchMode.inAppBrowserView) {
          throw Exception('no in-app browser');
        }
        return true;
      });
      expect(fallback, isTrue);
      expect(modes.last, LaunchMode.externalApplication);

      final nothing = await openInAppThenBrowser(room,
          launch: (uri, mode) async => throw Exception('nothing'));
      expect(nothing, isFalse);
    });

    test('our own site is ours; others are not', () {
      expect(isOwnSite(room), isTrue);
      expect(isOwnSite(Uri.parse('https://events.myotherapp.in/x')), isTrue);
      expect(isOwnSite(Uri.parse('https://instagram.com/x')), isFalse);
      expect(isOwnSite(Uri.parse('mailto:support@myotherapp.in')), isFalse);
    });
  });

  group('the event page opens the live room', () {
    late RouteAdapter api;

    setUp(() {
      api = useFakeApi();
      api.on('GET', '/events/info/68', {
        'id': 68,
        'name': 'Hack Night',
        'event_datetime': '2030-12-01T10:00:00Z',
        'duration': 2,
        'reg_startdate': '2020-01-01T00:00:00Z',
        'club': {'id': 3, 'name': 'Tinkerhub'},
        'category': {'id': 1, 'name': 'Tech'},
      });
    });

    Future<List<Uri>> pumpEvent(WidgetTester tester,
        {required bool openLiveRoom, bool launches = true}) async {
      final opened = <Uri>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
          linkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return launches;
          }),
        ],
        child: MaterialApp(
          home: IndividualEventPage(eventId: 68, openLiveRoom: openLiveRoom),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return opened;
    }

    testWidgets('at once, from a "join now" push, through the in-app launcher',
        (tester) async {
      final opened = await pumpEvent(tester, openLiveRoom: true);

      // The room under the event's own address; the website sends an id
      // on to the slug.
      expect(opened, [Uri.parse('https://myotherapp.in/events/68/live')]);
      // The event is underneath: closing the room lands on it.
      expect(find.byType(IndividualEventPage), findsOneWidget);
    });

    testWidgets('not when opened any other way', (tester) async {
      final opened = await pumpEvent(tester, openLiveRoom: false);
      expect(opened, isEmpty);
    });

    testWidgets('and says so when nothing could open it', (tester) async {
      await pumpEvent(tester, openLiveRoom: true, launches: false);
      expect(find.text("Couldn't open the live room"), findsOneWidget);
    });
  });

  group('event_live_join', () {
    test('routes to the event, told to open its room', () {
      expect(NotificationService.routeFor(_quizPush), '/events/68?live=quiz');
      expect(
        NotificationService.routeFor(const {
          'type': 'event_live_join',
          'event_id': 68,
          'what': 'poll',
        }),
        '/events/68?live=poll',
      );
      expect(
        NotificationService.routeFor(const {
          'type': 'event_live_join',
          'event_id': '68',
          'what': 'something new',
        }),
        '/events/68?live=room',
      );
    });

    test('without a usable event id goes nowhere', () {
      expect(
          NotificationService.routeFor(const {'type': 'event_live_join'}),
          isNull);
      expect(
          NotificationService.routeFor(
              const {'type': 'event_live_join', 'event_id': 'abc'}),
          isNull);
    });

    test('its inbox row opens the same way', () {
      final row = NotificationModel.fromJson({
        'id': 'n1',
        'user_id': 1,
        'title': 'Hack Night',
        'description': 'The quiz is starting — join now',
        'type': 'event_live_join',
        'status': 'unread',
        'data': {..._quizPush},
        'created_at': '2026-10-19T08:00:00Z',
        'updated_at': '2026-10-19T08:00:00Z',
      });

      expect(row.notificationType, NotificationType.eventLiveJoin);
      expect(row.liveEventId, 68);
      expect(row.liveWhat, 'quiz');
      expect(NotificationService.liveJoinRoute(row.liveEventId!, row.liveWhat),
          NotificationService.routeFor(_quizPush));
      expect(row.iconEmoji, '🧠');
    });

    test('is opened once per push_id', () {
      final dedupe = PushDedupe();
      expect(dedupe.firstOpen(_quizPush), isTrue);
      expect(dedupe.firstOpen({..._quizPush}), isFalse,
          reason: 'a second copy of the same push');
      expect(dedupe.firstOpen({..._quizPush, 'push_id': 'another'}), isTrue);
    });
  });

  group('a cold start from the push', () {
    setUp(NotificationService.pendingLaunch.clear);
    tearDown(NotificationService.pendingLaunch.clear);

    GoRouter router() => GoRouter(
          initialLocation: '/splash',
          routes: [
            GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
            GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
            GoRoute(
              path: '/events/:eventId',
              builder: (_, state) => Text(
                  'EVENT ${state.pathParameters['eventId']} '
                  'live=${state.uri.queryParameters['live']}'),
            ),
            GoRoute(
              path: '/auth/onboarding',
              builder: (_, __) => const Text('SIGN IN'),
            ),
          ],
        );

    testWidgets('opens the event over home, with the room to follow; Back '
        'lands on home through the event', (tester) async {
      final payload = '{"type":"event_live_join","event_id":"68",'
          '"what":"quiz","push_id":"cold-start-1"}';
      NotificationService.holdLaunchPayload(payload);
      final r = router();
      addTearDown(r.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => _FakeAuth(const AuthState(
                accessToken: 'token',
                isInitialized: true,
              ))),
        ],
        child: MaterialApp.router(routerConfig: r),
      ));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // The event page, asked to open its live room: the room opens on top
      // of it (in-app browser), so closing the room shows the event.
      expect(find.text('EVENT 68 live=quiz'), findsOneWidget);
      r.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    test('a launch tap counts as the push being opened: a second copy '
        'tapped later opens nothing', () {
      const payload = '{"type":"event_live_join","event_id":"68",'
          '"what":"poll","push_id":"cold-start-2"}';
      NotificationService.holdLaunchPayload(payload);
      expect(NotificationService.pendingLaunch.take(), '/events/68?live=poll');

      expect(
        NotificationService.dedupe.firstOpen(const {
          'type': 'event_live_join',
          'event_id': '68',
          'what': 'poll',
          'push_id': 'cold-start-2',
        }),
        isFalse,
      );

      // And the same launch reported twice holds nothing more.
      NotificationService.holdLaunchPayload(payload);
      expect(NotificationService.pendingLaunch.take(), isNull);
    });
  });
}
