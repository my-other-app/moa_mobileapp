import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// A data source that returns or throws whatever a test asks it to.
///
/// The point of the repository layer is that this is possible at all: before
/// it, the notifier called `APIService.instance` directly and could only be
/// tested by standing up HTTP.
class _FakeDataSource implements NotificationRemoteDataSource {
  Object? throws;
  NotificationPage page = const NotificationPage(items: [], total: 0);
  int count = 0;
  final List<String> calls = [];

  @override
  Future<NotificationPage> fetchList({
    required int limit,
    required int offset,
    String? cursor,
  }) async {
    calls.add(cursor == null
        ? 'fetchList($limit,$offset)'
        : 'fetchList($limit,$offset,$cursor)');
    if (throws != null) throw throws!;
    return page;
  }

  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => null;

  @override
  Future<int> unreadCount() async {
    calls.add('unreadCount');
    if (throws != null) throw throws!;
    return count;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    calls.add('markAsRead($notificationId)');
    if (throws != null) throw throws!;
  }

  @override
  Future<void> markAllAsRead() async {
    calls.add('markAllAsRead');
    if (throws != null) throw throws!;
  }
}

NotificationModel _notification({String id = 'n1', String status = 'unread'}) {
  return NotificationModel(
    id: id,
    userId: 1,
    title: 'Hack Night 04',
    description: 'Doors open at 7',
    type: 'event',
    status: status,
    createdAt: DateTime(2026, 10, 7),
    updatedAt: DateTime(2026, 10, 7),
  );
}

void main() {
  late _FakeDataSource dataSource;
  late NotificationRepositoryImpl repository;

  setUp(() {
    dataSource = _FakeDataSource();
    repository = NotificationRepositoryImpl(remoteDataSource: dataSource);
  });

  group('fetchList', () {
    test('returns the page on success', () async {
      dataSource.page = NotificationPage(items: [_notification()], total: 1);

      final result = await repository.fetchList(limit: 20, offset: 0);

      expect(result.isRight, isTrue);
      expect(result.right.items.single.id, 'n1');
      expect(dataSource.calls.single, 'fetchList(20,0)');
    });

    test('passes the server\'s cursor through for the next page', () async {
      await repository.fetchList(limit: 20, offset: 20, cursor: 'abc');

      expect(dataSource.calls.single, 'fetchList(20,20,abc)');
    });

    test('maps an unauthorized ApiException to AuthFailure', () async {
      dataSource.throws = const ApiException(
        message: 'Token expired',
        type: ApiExceptionType.unauthorized,
      );

      final result = await repository.fetchList(limit: 20, offset: 0);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<AuthFailure>());
      expect(result.left.message, 'Token expired');
    });

    test('maps a timeout to NetworkFailure, not UnknownFailure', () async {
      // The distinction the UI acts on: a network failure is worth a retry
      // button, an unknown one is not.
      dataSource.throws = const ApiException(
        message: 'Connection timed out',
        type: ApiExceptionType.timeout,
      );

      final result = await repository.fetchList(limit: 20, offset: 0);

      expect(result.left, isA<NetworkFailure>());
    });

    test('turns an unexpected throw into a Failure rather than escaping',
        () async {
      // A parse error inside the data source must not propagate as a raw
      // exception -- the notifier has no catch any more, by design.
      dataSource.throws = TypeError();

      final result = await repository.fetchList(limit: 20, offset: 0);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<UnknownFailure>());
    });
  });

  group('writes', () {
    test('markAsRead reports success', () async {
      final result = await repository.markAsRead('n1');

      expect(result.isRight, isTrue);
      expect(dataSource.calls.single, 'markAsRead(n1)');
    });

    test('markAsRead reports failure instead of swallowing it', () async {
      /*
       * The behaviour this replaces: the notifier wrapped each call in a
       * bare `try/catch {}` with the comment "Handle error silently", so a
       * failed mark-as-read looked exactly like a successful one and the UI
       * crossed the notification off anyway.
       */
      dataSource.throws = const ApiException(
        message: 'Server error',
        type: ApiExceptionType.server,
      );

      final result = await repository.markAsRead('n1');

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ServerFailure>());
    });

    test('markAllAsRead reports failure too', () async {
      dataSource.throws = const ApiException(
        message: 'nope',
        type: ApiExceptionType.forbidden,
      );

      expect((await repository.markAllAsRead()).isLeft, isTrue);
    });
  });

  group('NotificationModel.copyWithStatus', () {
    test('changes only the status and the timestamp', () {
      final original = _notification();

      final read = original.copyWithStatus('read');

      expect(read.status, 'read');
      // Every other field survives. The hand-rolled rebuild this replaces
      // had twelve fields to drop at each of two call sites.
      expect(read.id, original.id);
      expect(read.userId, original.userId);
      expect(read.title, original.title);
      expect(read.description, original.description);
      expect(read.type, original.type);
      expect(read.createdAt, original.createdAt);
    });
  });
}
