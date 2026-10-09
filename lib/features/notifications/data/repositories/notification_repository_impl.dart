import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';

/// Provider for the notification repository.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    remoteDataSource: ref.watch(notificationRemoteDataSourceProvider),
  );
});

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<NotificationPage>> fetchList({
    required int limit,
    required int offset,
  }) =>
      _guard(
        () => remoteDataSource.fetchList(limit: limit, offset: offset),
        'fetchList',
      );

  @override
  Future<Result<int>> unreadCount() =>
      _guard(remoteDataSource.unreadCount, 'unreadCount');

  @override
  Future<Result<void>> markAsRead(String notificationId) =>
      _guard(() => remoteDataSource.markAsRead(notificationId), 'markAsRead');

  @override
  Future<Result<void>> markAllAsRead() =>
      _guard(remoteDataSource.markAllAsRead, 'markAllAsRead');

  /// Run one data-source call and convert anything thrown into a [Failure].
  ///
  /// One helper rather than the same try/catch pasted into every method: the
  /// pasted version is where a `catch` quietly goes missing.
  Future<Result<T>> _guard<T>(
    Future<T> Function() call,
    String label,
  ) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('NotificationRepository.$label error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }
}
