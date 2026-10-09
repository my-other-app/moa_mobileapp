import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';

/// State for notification list
class NotificationsState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int unreadCount;
  final bool hasMore;
  final int currentOffset;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.unreadCount = 0,
    this.hasMore = true,
    this.currentOffset = 0,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? unreadCount,
    bool? hasMore,
    int? currentOffset,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
    );
  }
}

/// Provider for notification list management
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository) : super(const NotificationsState());

  final NotificationRepository _repository;

  static const int _pageSize = 20;

  /// Load initial notifications
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.fetchList(limit: _pageSize, offset: 0);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        // The failure's own message, not e.toString(): the repository has
        // already turned a transport error into something a person can read.
        error: failure.message,
      ),
      (page) {
        state = state.copyWith(
          notifications: page.items,
          isLoading: false,
          hasMore: page.items.length >= _pageSize,
          currentOffset: page.items.length,
        );
      },
    );

    if (result.isRight) await fetchUnreadCount();
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await _repository.fetchList(
      limit: _pageSize,
      offset: state.currentOffset,
    );

    result.fold(
      (_) => state = state.copyWith(isLoadingMore: false),
      (page) {
        state = state.copyWith(
          notifications: [...state.notifications, ...page.items],
          isLoadingMore: false,
          hasMore: page.items.length >= _pageSize,
          currentOffset: state.currentOffset + page.items.length,
        );
      },
    );
  }

  /// Fetch unread notification count
  Future<void> fetchUnreadCount() async {
    final result = await _repository.unreadCount();
    // A failed count is not worth surfacing: the badge keeps its previous
    // value rather than flashing an error over a screen nobody asked to
    // refresh.
    result.fold((_) {}, (count) => state = state.copyWith(unreadCount: count));
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final result = await _repository.markAsRead(notificationId);
    if (result.isLeft) return;

    state = state.copyWith(
      notifications: [
        for (final n in state.notifications)
          if (n.id == notificationId) n.copyWithStatus('read') else n,
      ],
      unreadCount: (state.unreadCount - 1).clamp(0, 9999),
    );
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final result = await _repository.markAllAsRead();
    if (result.isLeft) return;

    state = state.copyWith(
      notifications: [
        for (final n in state.notifications) n.copyWithStatus('read'),
      ],
      unreadCount: 0,
    );
  }

  /// Refresh notifications (pull to refresh)
  Future<void> refresh() async {
    state = state.copyWith(
      hasMore: true,
      currentOffset: 0,
    );
    await loadNotifications();
  }
}

/// Provider instance
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(ref.watch(notificationRepositoryProvider)),
);

/// Provider for just unread count (useful for badges in nav)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
