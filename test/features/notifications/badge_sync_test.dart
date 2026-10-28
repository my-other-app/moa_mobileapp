import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/services/app_badge.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finnet/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/services/app_badge_fakes.dart';

NotificationModel _line(String id, {String status = 'unread'}) =>
    NotificationModel(
      id: id,
      userId: 1,
      title: 'Line $id',
      description: '',
      type: 'club_thread',
      status: status,
      createdAt: DateTime(2026, 10, 29, 9),
      updatedAt: DateTime(2026, 10, 29, 9),
    );

/// The server's inbox: its lines, and its unread count, which a read or
/// "Mark all read" changes as the server's would. A count read can be held,
/// or fail.
class _Server implements NotificationRepository {
  _Server(this.lines);

  List<NotificationModel> lines;
  bool countFails = false;
  bool markFails = false;
  Completer<void>? holdCount;
  int countReads = 0;

  int get unread => lines.where((n) => n.isUnread).length;

  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => null;

  @override
  Future<Result<NotificationPage>> fetchList({
    required int limit,
    required int offset,
    String? cursor,
  }) async =>
      Either.right(NotificationPage(items: lines, total: lines.length));

  @override
  Future<Result<int>> unreadCount() async {
    countReads++;
    // The count as it was when the request reached the server.
    final count = unread;
    if (holdCount != null) await holdCount!.future;
    if (countFails) return Either.left(const NetworkFailure());
    return Either.right(count);
  }

  final List<String> marked = [];

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    marked.add(notificationId);
    if (markFails) return Either.left(const NetworkFailure());
    lines = [
      for (final n in lines)
        if (n.id == notificationId) n.copyWithStatus('read') else n,
    ];
    return Either.right(null);
  }

  /// The server's answer to a tapped push: [keys] maps a send's key to
  /// the reader's own line; an id is the line itself.
  final Map<String, String> keys = {};
  final List<String> opened = [];
  bool openFails = false;
  Completer<void>? holdOpen;

  @override
  Future<Result<String>> markOpened(String id) async {
    opened.add(id);
    if (holdOpen != null) await holdOpen!.future;
    if (openFails) return Either.left(const NetworkFailure());
    final lineId = keys[id] ?? id;
    if (!lines.any((n) => n.id == lineId)) {
      return Either.left(
          const ServerFailure(message: 'Not found', code: '404'));
    }
    lines = [
      for (final n in lines)
        if (n.id == lineId) n.copyWithStatus('read') else n,
    ];
    return Either.right(lineId);
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    if (markFails) return Either.left(const NetworkFailure());
    lines = [for (final n in lines) n.copyWithStatus('read')];
    return Either.right(null);
  }
}

void main() {
  late FakeBadgeChannel icon;
  late _Server server;
  late NotificationsNotifier inbox;

  setUp(() {
    icon = FakeBadgeChannel.install();
    server = _Server(
        [_line('a'), _line('b'), _line('c'), _line('d', status: 'read')]);
    final container = ProviderContainer(overrides: [
      notificationRepositoryProvider.overrideWithValue(server),
      appBadgeProvider.overrideWithValue(icon.badge()),
    ]);
    addTearDown(container.dispose);
    inbox = container.read(notificationsProvider.notifier);
  });

  test('reading the inbox puts its unread count on the icon', () async {
    await inbox.loadNotifications();

    expect(inbox.state.unreadCount, 3);
    expect(icon.counts, [3]);
  });

  test('the count read on its own (start-up, back to the front) sets it too',
      () async {
    await inbox.fetchUnreadCount();
    expect(icon.shown, 3);
  });

  test('opening a line marks it read, and the icon follows the server',
      () async {
    await inbox.loadNotifications();

    await inbox.markAsRead('b');

    expect(inbox.state.unreadCount, 2);
    expect(icon.shown, 2);
    expect(server.countReads, 2, reason: 'read again after the mark');
  });

  test('the last unread line read: 0, which takes the number off', () async {
    server.lines = [_line('only')];
    await inbox.loadNotifications();
    expect(icon.shown, 1);

    await inbox.markAsRead('only');

    expect(icon.shown, 0);
  });

  test('"Mark all read" clears the icon at once', () async {
    await inbox.loadNotifications();

    await inbox.markAllAsRead();

    expect(inbox.state.unreadCount, 0);
    expect(icon.counts, [3, 0]);
  });

  test('nothing unread on the server is 0, never left as it was', () async {
    server.lines = [_line('old', status: 'read')];

    await inbox.loadNotifications();

    expect(icon.counts, [0]);
  });

  test('a count that cannot be read leaves the icon alone', () async {
    await inbox.fetchUnreadCount();
    server.countFails = true;

    await inbox.fetchUnreadCount();

    expect(icon.counts, [3]);
  });

  test('a mark the server refused changes nothing', () async {
    await inbox.loadNotifications();
    server.markFails = true;

    await inbox.markAsRead('a');
    await inbox.markAllAsRead();

    expect(icon.counts, [3]);
    expect(inbox.state.unreadCount, 3);
  });

  test('a count read before "Mark all read" that answers after it is stale',
      () async {
    await inbox.loadNotifications();
    final hold = server.holdCount = Completer<void>();
    final slow = inbox.fetchUnreadCount();
    await Future<void>.delayed(Duration.zero);

    server.holdCount = null;
    await inbox.markAllAsRead();
    // The old read answers now, with the count from before.
    hold.complete();
    await slow;

    expect(inbox.state.unreadCount, 0);
    expect(icon.shown, 0);
  });

  test('of two count reads, only the newer one sets the icon', () async {
    final hold = server.holdCount = Completer<void>();
    final older = inbox.fetchUnreadCount();
    await Future<void>.delayed(Duration.zero);

    server.holdCount = null;
    await inbox.markAsRead('a'); // the server is at 2; this reads it again
    hold.complete();
    await older;

    expect(icon.shown, 2);
    expect(inbox.state.unreadCount, 2);
  });

  group('a tapped push marks its line read', () {
    test('by the line\'s id: shown read, and the icon follows', () async {
      await inbox.loadNotifications();

      await inbox.markOpened('a');

      expect(server.opened, ['a']);
      expect(inbox.state.notifications.firstWhere((n) => n.id == 'a').isUnread,
          isFalse);
      expect(inbox.state.unreadCount, 2);
      expect(icon.shown, 2);
    });

    test('by its send\'s key: the reader\'s own line', () async {
      server.keys['key-announce'] = 'b';
      await inbox.loadNotifications();

      await inbox.markOpened('key-announce');

      expect(inbox.state.notifications.firstWhere((n) => n.id == 'b').isUnread,
          isFalse);
      expect(icon.shown, 2);
    });

    test(
        'before the inbox was ever read (a cold start): the count still '
        'follows', () async {
      await inbox.markOpened('c');

      expect(server.opened, ['c']);
      expect(icon.counts, [2]);
    });

    test(
        'once, however often it is asked -- the launch tap, then the inbox '
        'opening on the same line', () async {
      final hold = server.holdOpen = Completer<void>();
      final first = inbox.markOpened('a');
      final second = inbox.markOpened('a');
      hold.complete();
      await Future.wait([first, second]);
      await inbox.markOpened('a');

      // The inbox lists it read; a tap on it there sends nothing more.
      await inbox.loadNotifications();
      await inbox.markAsRead('a');

      expect(server.opened, ['a']);
      expect(server.marked, isEmpty);
      expect(icon.shown, 2);
    });

    test('a page read before the server had the mark still shows it read',
        () async {
      await inbox.markOpened('a');
      // The list's answer left the server before the mark landed.
      server.lines = [
        for (final n in server.lines)
          if (n.id == 'a') n.copyWithStatus('unread') else n,
      ];

      await inbox.loadNotifications();

      expect(inbox.state.notifications.firstWhere((n) => n.id == 'a').isUnread,
          isFalse);
    });

    test('a mark that fails is let go: nothing thrown, the count read again',
        () async {
      await inbox.loadNotifications();
      server.openFails = true;

      await expectLater(inbox.markOpened('a'), completes);

      expect(inbox.state.notifications.firstWhere((n) => n.id == 'a').isUnread,
          isTrue);
      expect(icon.shown, 3);
    });

    test(
        'a line the server does not know (another account\'s) changes '
        'nothing', () async {
      await inbox.loadNotifications();

      await inbox.markOpened('not-mine');

      expect(inbox.state.notifications.where((n) => n.isUnread), hasLength(3));
      expect(icon.shown, 3);
    });
  });
}
