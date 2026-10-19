import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/network_status.dart';
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

  /// The server's cursor for the next page, when it pages by keyset.
  final String? nextCursor;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.unreadCount = 0,
    this.hasMore = true,
    this.currentOffset = 0,
    this.nextCursor,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? unreadCount,
    bool? hasMore,
    int? currentOffset,
    String? Function()? nextCursor,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    );
  }
}

/// Provider for notification list management
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository) : super(const NotificationsState());

  final NotificationRepository _repository;

  static const int _pageSize = 20;

  /// Load initial notifications: the first page saved on this phone at
  /// once, when there is one and nothing is on screen yet, then the
  /// server's.
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    if (state.notifications.isEmpty) {
      final saved = await _repository.savedFirstPage(limit: _pageSize);
      if (!mounted) return;
      if (saved != null && saved.items.isNotEmpty) {
        state = state.copyWith(
          notifications: saved.items,
          isLoading: false,
          hasMore: false,
          currentOffset: saved.items.length,
        );
      }
    }

    final result = await _repository.fetchList(limit: _pageSize, offset: 0);
    if (!mounted) return;

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        // The failure's own message, not e.toString(): the repository has
        // already turned a transport error into something a person can read.
        // With the saved page on screen, a failed refresh is not an error.
        error: state.notifications.isEmpty ? failure.message : null,
      ),
      (page) {
        state = state.copyWith(
          notifications: page.items,
          isLoading: false,
          hasMore: page.items.length >= _pageSize,
          currentOffset: page.items.length,
          nextCursor: () => page.nextCursor,
        );
      },
    );

    if (result.isRight && mounted) await fetchUnreadCount();
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    // By the server's cursor when it gave one: the next page does not shift
    // when newer lines arrive. The offset stays for a server without.
    final result = await _repository.fetchList(
      limit: _pageSize,
      offset: state.currentOffset,
      cursor: state.nextCursor,
    );
    if (!mounted) return;

    result.fold(
      (_) => state = state.copyWith(isLoadingMore: false),
      (page) {
        state = state.copyWith(
          notifications: [...state.notifications, ...page.items],
          isLoadingMore: false,
          hasMore: page.items.length >= _pageSize,
          currentOffset: state.currentOffset + page.items.length,
          nextCursor: () => page.nextCursor,
        );
      },
    );
  }

  /// Fetch unread notification count
  Future<void> fetchUnreadCount() async {
    final result = await _repository.unreadCount();
    if (!mounted) return;
    // A failed count is not worth surfacing: the badge keeps its previous
    // value rather than flashing an error over a screen nobody asked to
    // refresh.
    result.fold((_) {}, (count) => state = state.copyWith(unreadCount: count));
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final result = await _repository.markAsRead(notificationId);
    if (result.isLeft || !mounted) return;

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
    if (result.isLeft || !mounted) return;

    state = state.copyWith(
      notifications: [
        for (final n in state.notifications) n.copyWithStatus('read'),
      ],
      unreadCount: 0,
    );
  }

  /// Back online: read again, if the list was read (or failed) before and
  /// is not being read now (the offline state on screen may already have
  /// asked).
  void reloadIfShown() {
    if (state.isLoading) return;
    if (state.notifications.isNotEmpty || state.error != null) {
      loadNotifications();
    }
  }

  /// Refresh notifications (pull to refresh)
  Future<void> refresh() async {
    state = state.copyWith(
      hasMore: true,
      currentOffset: 0,
      nextCursor: () => null,
    );
    await loadNotifications();
  }
}

/// Provider instance
///
/// Read again when the app comes back online, if it has been read at all.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final notifier =
      NotificationsNotifier(ref.watch(notificationRepositoryProvider));
  ref.listen<int>(backOnlineProvider, (_, __) {
    if (notifier.mounted) notifier.reloadIfShown();
  });
  return notifier;
});

/// Provider for just unread count (useful for badges in nav)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
