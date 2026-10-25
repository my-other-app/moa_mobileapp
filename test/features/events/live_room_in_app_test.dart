import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/push_dedupe.dart';
import 'package:finnet/features/auth/presentation/pages/splash_screen.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/presentation/pages/live_room_page.dart';
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
      api.on('GET', '/events/68/live', {
        'event': {'id': 68, 'name': 'Hack Night', 'status': 'live'},
        'banner': {'kind': 'room', 'text': 'Demos move to Lab 3B'},
        'updates': [
          {
            'id': 'u1',
            'kind': 'room',
            'text': 'Demos move to Lab 3B',
            'sent_at': '2030-12-01T10:30:00Z',
          },
        ],
        'poll': null,
        'questions': <dynamic>[],
        'qa': {'open': true, 'approve_first': false},
        'quiz': {'live': false, 'title': null},
      });
    });

    Future<void> pumpEvent(WidgetTester tester,
        {required bool openLiveRoom}) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
          liveIdentityProvider
              .overrideWithValue(LiveIdentity(MemoryLiveStore())),
        ],
        child: MaterialApp(
          home: IndividualEventPage(eventId: 68, openLiveRoom: openLiveRoom),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('at once, when asked, as the app\'s own screen on top',
        (tester) async {
      await pumpEvent(tester, openLiveRoom: true);

      expect(find.byType(LiveRoomPage), findsOneWidget);
      Finder inRoom(Finder f) =>
          find.descendant(of: find.byType(LiveRoomPage), matching: f);
      expect(inRoom(find.text('Demos move to Lab 3B')), findsOneWidget);
      expect(inRoom(find.text('Ask the room')), findsOneWidget);

      // The event is underneath: Back lands on it.
      await tester.tap(find.descendant(
          of: find.byType(LiveRoomPage), matching: find.byType(BackButton)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LiveRoomPage), findsNothing);
      expect(find.byType(IndividualEventPage), findsOneWidget);
    });

    testWidgets('not when opened any other way', (tester) async {
      await pumpEvent(tester, openLiveRoom: false);
      expect(find.byType(LiveRoomPage), findsNothing);
    });
  });

  group('every live push opens the room in the app', () {
    test('the quiz starting opens the quiz, to join with the code', () {
      expect(NotificationService.routeFor(_quizPush), '/events/68/live/quiz');
    });

    test('a poll, the event going live, questions opening and updates open '
        'the room', () {
      for (final data in [
        const {'type': 'event_live_join', 'event_id': 68, 'what': 'poll'},
        const {'type': 'event_live_join', 'event_id': '68', 'what': 'new'},
        const {'type': 'event_live_started', 'event_id': '68', 'what': 'room'},
        const {'type': 'event_live_qa', 'event_id': '68', 'what': 'qa'},
        const {'type': 'event_live_update', 'event_id': '68'},
      ]) {
        expect(NotificationService.routeFor(data), '/events/68/live',
            reason: '$data');
      }
      // Whatever the type, `what: quiz` is the quiz.
      expect(
          NotificationService.routeFor(const {
            'type': 'event_live_started',
            'event_id': '68',
            'what': 'quiz',
          }),
          '/events/68/live/quiz');
    });

    test('without a usable event id goes nowhere', () {
      for (final type in NotificationService.liveRoomTypes) {
        expect(NotificationService.routeFor({'type': type}), isNull);
        expect(
            NotificationService.routeFor({'type': type, 'event_id': 'abc'}),
            isNull);
      }
    });

    NotificationModel row(String type, Map<String, dynamic> data) =>
        NotificationModel.fromJson({
          'id': 'n1',
          'user_id': 1,
          'title': 'Hack Night',
          'description': 'Something in the room',
          'type': type,
          'status': 'unread',
          'data': data,
          'created_at': '2026-10-19T08:00:00Z',
          'updated_at': '2026-10-19T08:00:00Z',
        });

    test('their inbox rows open the same way', () {
      final quiz = row('event_live_join', {..._quizPush});
      expect(quiz.notificationType, NotificationType.eventLiveJoin);
      expect(quiz.liveEventId, 68);
      expect(quiz.liveWhat, 'quiz');
      expect(quiz.opensLiveRoom, isTrue);
      expect(NotificationService.liveJoinRoute(quiz.liveEventId!, quiz.liveWhat),
          NotificationService.routeFor(_quizPush));
      expect(quiz.iconEmoji, '🧠');

      for (final (type, kind) in [
        ('event_live_started', NotificationType.eventLiveStarted),
        ('event_live_qa', NotificationType.eventLiveQa),
        ('event_live_update', NotificationType.eventLiveUpdate),
      ]) {
        final r = row(type, {'type': type, 'event_id': '68'});
        expect(r.notificationType, kind);
        expect(r.opensLiveRoom, isTrue);
        expect(NotificationService.liveJoinRoute(r.liveEventId!, r.liveWhat),
            '/events/68/live');
      }
      expect(row('event_reminder', {'event_id': '68'}).opensLiveRoom, isFalse);
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
              path: '/events/:eventId/live',
              builder: (_, state) =>
                  Text('ROOM ${state.pathParameters['eventId']}'),
              routes: [
                GoRoute(
                  path: 'quiz',
                  builder: (_, state) =>
                      Text('QUIZ ${state.pathParameters['eventId']}'),
                ),
              ],
            ),
            GoRoute(
              path: '/auth/onboarding',
              builder: (_, __) => const Text('SIGN IN'),
            ),
          ],
        );

    testWidgets('opens the quiz over home; Back lands on home',
        (tester) async {
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

      expect(find.text('QUIZ 68'), findsOneWidget);
      r.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    test('a launch tap counts as the push being opened: a second copy '
        'tapped later opens nothing', () {
      const payload = '{"type":"event_live_join","event_id":"68",'
          '"what":"poll","push_id":"cold-start-2"}';
      NotificationService.holdLaunchPayload(payload);
      expect(NotificationService.pendingLaunch.take(), '/events/68/live');

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
