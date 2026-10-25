import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finnet/features/profile/presentation/pages/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

NotificationModel _row(String id, String type, String title,
        {Map<String, dynamic>? data, bool withEvent = true}) =>
    NotificationModel.fromJson({
      'id': id,
      'user_id': 1,
      'title': title,
      'description': 'From the live room',
      'type': type,
      'status': 'unread',
      if (withEvent) 'event': {'id': 68, 'name': 'Hack Night'},
      'data': {'type': type, 'event_id': '68', ...?data},
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

class _Inbox implements NotificationRepository {
  _Inbox(this.items);
  final List<NotificationModel> items;
  final List<String> read = [];

  @override
  Future<Result<NotificationPage>> fetchList(
          {required int limit, required int offset, String? cursor}) async =>
      Either.right(NotificationPage(items: items, total: items.length));

  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => null;

  @override
  Future<Result<int>> unreadCount() async => Either.right(items.length);

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    read.add(notificationId);
    return Either.right(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async => Either.right(null);
}

void main() {
  Future<_Inbox> pumpInbox(
      WidgetTester tester, List<NotificationModel> rows) async {
    final inbox = _Inbox(rows);
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(
            path: '/inbox', builder: (_, __) => const NotificationsNewPage()),
        GoRoute(
          path: '/events/:id/live',
          builder: (_, s) => Text('ROOM ${s.pathParameters['id']}'),
          routes: [
            GoRoute(
              path: 'quiz',
              builder: (_, s) => Text('QUIZ ${s.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(inbox)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return inbox;
  }

  for (final (type, title) in [
    ('event_live_update', 'Demos move to Lab 3B'),
    ('event_live_started', 'Hack Night is live'),
    ('event_live_qa', 'Questions are open'),
  ]) {
    testWidgets('a $type row opens the event\'s live room', (tester) async {
      final inbox = await pumpInbox(tester, [_row('n1', type, title)]);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('ROOM 68'), findsOneWidget);
      expect(inbox.read, ['n1']);
    });
  }

  testWidgets('a "quiz is starting" row opens the quiz', (tester) async {
    await pumpInbox(tester, [
      _row('n2', 'event_live_join', 'The quiz is starting',
          data: {'what': 'quiz'}),
    ]);
    await tester.tap(find.text('The quiz is starting'));
    await tester.pumpAndSettle();
    expect(find.text('QUIZ 68'), findsOneWidget);
  });

  testWidgets('a row without its event still opens the room from its data',
      (tester) async {
    await pumpInbox(tester, [
      _row('n3', 'event_live_update', 'Doors at 6', withEvent: false),
    ]);
    await tester.tap(find.text('Doors at 6'));
    await tester.pumpAndSettle();
    expect(find.text('ROOM 68'), findsOneWidget);
  });
}
