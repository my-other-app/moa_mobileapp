import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/services/notification_routes.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/quests/quest_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// An auth state set by hand, without the real notifier's storage read.
class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  group('the unlock pushes', () {
    test('"You unlocked Tier 1" opens the event\'s quest', () {
      // The push as the contract sends it (§10).
      expect(
          NotificationService.routeFor(const {
            'type': 'quest_unlocked',
            'event_id': '1',
            'open': 'quest',
            'notification_id': 'n-1',
          }),
          '/events/1/quest');
      expect(
          NotificationService.routeFor(
              const {'type': 'quest_reward_held', 'event_id': '1'}),
          '/events/1/quest');
    });

    test('any push that says open: quest, with its event', () {
      expect(
          notificationRoute('event_reminder',
              eventId: 4, data: const {'open': 'quest'}),
          '/events/4/quest');
      expect(questPushRoute('event_reminder', 4, null), isNull);
    });

    test('without an event: nowhere', () {
      expect(NotificationService.routeFor(const {'type': 'quest_unlocked'}),
          isNull);
    });

    test('its line in the inbox opens the same place', () {
      final line = NotificationModel.fromJson(const {
        'id': 'n-1',
        'type': 'quest_unlocked',
        'title': '🎁 You unlocked Tier 1',
        'description': 'DevFest T-shirt — collect at Swag desk.',
        'event': {'id': 1, 'name': 'DevFest'},
        'data': {'event_id': 1, 'milestone_id': 'm-1', 'open': 'quest'},
        'is_read': false,
        'created_at': '2026-11-28T05:00:00Z',
      });
      expect(line.route, '/events/1/quest');
    });
  });

  group('website links', () {
    String? at(String url) => webLocation(Uri.parse(url));

    test('an event\'s quest', () {
      expect(at('https://myotherapp.in/events/devfest-2026/quest'),
          '/events/devfest-2026/quest');
      expect(at('https://myotherapp.in/events/1/quest'), '/events/1/quest');
    });

    test('a quest\'s "meet people": the scanner, at the event', () {
      // The website's Quests card: the Network address, asking to scan.
      expect(at('https://myotherapp.in/network?event=1&scan=1'),
          '/network/scan?event=1');
      expect(at('https://myotherapp.in/network?scan=1&event=1'),
          '/network/scan?event=1');
      expect(at('https://myotherapp.in/network?event=1&scan=true'),
          '/network/scan?event=1');
      expect(at('https://myotherapp.in/network?scan=1'), '/network/scan');
      expect(at('/network?event=1&scan=1'), '/network/scan?event=1');
      expect(at('https://myotherapp.in/network/scan?event=1'),
          '/network/scan?event=1');
      expect(at('https://myotherapp.in/network/scan'), '/network/scan');
      expect(at('https://myotherapp.in/network/other'), isNull);
    });

    test('plain /network is the Network tab, as before', () {
      expect(at('https://myotherapp.in/network'), '/network');
      expect(at('https://myotherapp.in/network?event=9'), '/network?event=9');
      expect(at('https://myotherapp.in/network?event=9&scan=0'),
          '/network?event=9&scan=0');
    });
  });

  group('the website\'s scan link, through the router', () {
    late ProviderContainer container;

    GoRouter routerWith(AuthState auth) {
      container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(auth)),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      return container.read(routerProvider);
    }

    /// Where the router ends up for [location], redirects and all.
    Future<RouteMatchList> resolve(
        WidgetTester tester, GoRouter router, String location) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      return Future.value(router.configuration.redirect(
        context,
        router.configuration.findMatch(Uri.parse(location)),
        redirectHistory: [],
      ));
    }

    const link = 'https://myotherapp.in/network?event=1&scan=1';

    testWidgets('signed in: the scanner, with the event', (tester) async {
      final router =
          routerWith(const AuthState(accessToken: 't', isInitialized: true));
      final match = await resolve(tester, router, link);
      expect(match.isError, isFalse);
      expect(match.uri.toString(), '/network/scan?event=1');
      expect(match.last.route.name, 'savePersonScan');
      // Plain /network is still the tab.
      final tab =
          await resolve(tester, router, 'https://myotherapp.in/network');
      expect(tab.uri.toString(), '/network');
      expect(tab.last.route.name, AppRoutes.network);
    });

    testWidgets('signed out: sign in, then back to the scanner',
        (tester) async {
      final router = routerWith(const AuthState(isInitialized: true));
      final match = await resolve(tester, router, link);
      expect(match.uri.path, '/auth/onboarding');
      expect(match.uri.queryParameters['from'], '/network/scan?event=1');
    });
  });

  group('the router', () {
    test('/events/{ref}/quest is the quest page, not an event page', () {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) =>
            _FakeAuth(const AuthState(accessToken: 't', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      final match =
          router.configuration.findMatch(Uri.parse('/events/1/quest'));
      expect(match.last.route.name, 'eventQuest');
      expect(match.pathParameters['eventRef'], '1');
      // The event page and its own pages are still themselves.
      expect(
          router.configuration
              .findMatch(Uri.parse('/events/1'))
              .last
              .route
              .name,
          AppRoutes.eventDetail);
      expect(
          router.configuration
              .findMatch(Uri.parse('/events/1/live'))
              .last
              .route
              .name,
          'eventLive');
    });

    test('the quest page is open without an account', () {
      expect(
          authRedirect(const AuthState(isInitialized: true), questLocation(1)),
          isNull);
    });
  });
}
