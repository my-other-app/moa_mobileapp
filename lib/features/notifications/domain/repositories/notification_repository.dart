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
    String? cursor,
  });

  /// The first page as last saved on this phone, or null. No network.
  Future<NotificationPage?> savedFirstPage({required int limit});

  Future<Result<int>> unreadCount();

  Future<Result<void>> markAsRead(String notificationId);

  /// Mark read the line a tapped push named (its id, or its send's key).
  /// Answers the line's own id.
  Future<Result<String>> markOpened(String id);

  Future<Result<void>> markAllAsRead();
}
