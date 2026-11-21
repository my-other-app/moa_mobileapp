import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finnet/features/profile/presentation/pages/notifications/notifications_page.dart';
import 'package:finnet/features/quests/presentation/pages/quest_page.dart';
import 'package:finnet/features/quests/quest_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'quest_fixtures.dart';

/// A quest's notes in the inbox: their own mark, and the quest page they
/// open says whose quest it is.

NotificationModel _line(String id, String type, String title,
        {bool withEvent = true}) =>
    NotificationModel.fromJson({
      'id': id,
      'user_id': 1,
      'title': title,
      'description': 'DevFest T-shirt — collect at Swag desk.',
      'type': type,
      'status': 'unread',
      if (withEvent)
        'event': {'id': 1, 'name': 'Cloud Community Days x DevFest 2026'},
      // As the server writes a quest's note (app/api/quests/notify.py).
      'data': {
        'event_id': 1,
        'event_name': 'Cloud Community Days x DevFest 2026',
        'milestone_id': 'm-1',
        'open': 'quest',
      },
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

class _Inbox implements NotificationRepository {
  _Inbox(this.items);
  final List<NotificationModel> items;

  @override
  Future<Result<NotificationPage>> fetchList(
          {required int limit, required int offset, String? cursor}) async =>
      Either.right(NotificationPage(items: items, total: items.length));

  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => null;

  @override
  Future<Result<int>> unreadCount() async => Either.right(items.length);

  @override
  Future<Result<void>> markAsRead(String notificationId) async =>
      Either.right(null);

  @override
  Future<Result<String>> markOpened(String id) async => Either.right(id);

  @override
  Future<Result<void>> markAllAsRead() async => Either.right(null);
}

Future<void> _pumpInbox(
    WidgetTester tester, List<NotificationModel> rows) async {
  final router = GoRouter(
    initialLocation: '/inbox',
    routes: [
      GoRoute(path: '/inbox', builder: (_, __) => const NotificationsNewPage()),
      ...questRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(_Inbox(rows)),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test("a quest's note: the quest's mark, not the bell", () {
    final unlocked = _line('n1', 'quest_unlocked', '🎁 You unlocked Tier 1');
    final held =
        _line('n2', 'quest_reward_held', '🎁 Your DevFest T-shirt is waiting');
    expect(unlocked.isQuest, isTrue);
    expect(held.isQuest, isTrue);
    expect(unlocked.iconEmoji, '🎯');
    expect(held.iconEmoji, '🎯');
    expect(unlocked.route, '/events/1/quest');
    // Without the row's event, the name the note carries.
    expect(_line('n3', 'quest_unlocked', 'x', withEvent: false).eventName,
        'Cloud Community Days x DevFest 2026');
  });

  testWidgets('drawn on its own colour', (tester) async {
    useFakeApi().on('GET', '/events/1/quest', questJson());
    await _pumpInbox(
        tester, [_line('n1', 'quest_unlocked', '🎁 You unlocked Tier 1')]);
    expect(find.text('🎯'), findsOneWidget);
    expect(find.text('🔔'), findsNothing);
    final circle = tester.widget<Container>(find
        .ancestor(of: find.text('🎯'), matching: find.byType(Container))
        .first);
    expect((circle.decoration! as BoxDecoration).color, questNoteColor);
  });

  for (final withEvent in [true, false]) {
    testWidgets(
        'tapped: the quest page, with the event\'s name '
        '(${withEvent ? "the row's event" : "the note's data"})',
        (tester) async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      await _pumpInbox(tester, [
        _line('n1', 'quest_reward_held', '🎁 Your DevFest T-shirt is waiting',
            withEvent: withEvent),
      ]);
      await tester.tap(find.text('🎁 Your DevFest T-shirt is waiting'));
      await tester.pumpAndSettle();
      expect(find.byType(QuestPage), findsOneWidget);
      expect(find.byKey(QuestPage.eventNameKey), findsOneWidget);
      expect(find.text('Cloud Community Days x DevFest 2026'), findsOneWidget);
      // The name came with the tap: nothing asked for it.
      expect(api.sent('GET', '/discover/events/1'), isEmpty);
    });
  }
}
