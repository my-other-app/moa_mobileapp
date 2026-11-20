import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/services/notification_routes.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/quests/quest_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(at('https://myotherapp.in/network/scan?event=1'),
          '/network/scan?event=1');
      expect(at('https://myotherapp.in/network/scan'), '/network/scan');
      expect(at('https://myotherapp.in/network/other'), isNull);
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
