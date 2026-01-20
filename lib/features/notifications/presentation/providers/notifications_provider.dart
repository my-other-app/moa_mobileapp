import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/features/notifications/data/models/notification_model.dart';

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
  NotificationsNotifier() : super(const NotificationsState());

  static const int _pageSize = 20;

  /// Load initial notifications
  Future<void> loadNotifications() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await APIService.instance.request(
        '/api/v1/notifications/list',
        DioMethod.get,
        param: {
          'limit': _pageSize,
          'offset': 0,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['data'] ?? [];
        final notifications = items
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          notifications: notifications,
          isLoading: false,
          hasMore: notifications.length >= _pageSize,
          currentOffset: notifications.length,
        );

        // Also fetch unread count
        await fetchUnreadCount();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load notifications',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await APIService.instance.request(
        '/api/v1/notifications/list',
        DioMethod.get,
        param: {
          'limit': _pageSize,
          'offset': state.currentOffset,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['data'] ?? [];
        final newNotifications = items
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          notifications: [...state.notifications, ...newNotifications],
          isLoadingMore: false,
          hasMore: newNotifications.length >= _pageSize,
          currentOffset: state.currentOffset + newNotifications.length,
        );
      } else {
        state = state.copyWith(isLoadingMore: false);
      }
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Fetch unread notification count
  Future<void> fetchUnreadCount() async {
    try {
      final response = await APIService.instance.request(
        '/api/v1/notifications/unread-count',
        DioMethod.get,
      );

      if (response.statusCode == 200) {
        final count = response.data['count'] as int? ?? 0;
        state = state.copyWith(unreadCount: count);
      }
    } catch (e) {
      // Silently fail for count fetch
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await APIService.instance.request(
        '/api/v1/notifications/read/$notificationId',
        DioMethod.post,
      );

      if (response.statusCode == 200) {
        // Update local state
        final updatedNotifications = state.notifications.map((n) {
          if (n.id == notificationId) {
            return NotificationModel(
              id: n.id,
              userId: n.userId,
              title: n.title,
              description: n.description,
              type: n.type,
              status: 'read',
              fromClub: n.fromClub,
              event: n.event,
              data: n.data,
              createdAt: n.createdAt,
              updatedAt: DateTime.now(),
            );
          }
          return n;
        }).toList();

        state = state.copyWith(
          notifications: updatedNotifications,
          unreadCount: (state.unreadCount - 1).clamp(0, 9999),
        );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final response = await APIService.instance.request(
        '/api/v1/notifications/read-all',
        DioMethod.post,
      );

      if (response.statusCode == 200) {
        // Update local state - mark all as read
        final updatedNotifications = state.notifications.map((n) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            description: n.description,
            type: n.type,
            status: 'read',
            fromClub: n.fromClub,
            event: n.event,
            data: n.data,
            createdAt: n.createdAt,
            updatedAt: DateTime.now(),
          );
        }).toList();

        state = state.copyWith(
          notifications: updatedNotifications,
          unreadCount: 0,
        );
      }
    } catch (e) {
      // Handle error silently
    }
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
  (ref) => NotificationsNotifier(),
);

/// Provider for just unread count (useful for badges in nav)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
