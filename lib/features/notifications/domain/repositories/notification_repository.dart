import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';

/// What the presentation layer may ask of notifications.
///
/// Everything returns [Result], so a caller handles failure by pattern rather
/// than by catching: the provider that used to wrap each call in a bare
/// `try/catch {}` silently swallowed every error, which is why a failed
/// mark-as-read looked identical to a successful one.
abstract class NotificationRepository {
  Future<Result<NotificationPage>> fetchList({
    required int limit,
    required int offset,
  });

  Future<Result<int>> unreadCount();

  Future<Result<void>> markAsRead(String notificationId);

  Future<Result<void>> markAllAsRead();
}
