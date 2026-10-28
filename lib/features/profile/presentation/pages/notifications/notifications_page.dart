import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:finnet/features/profile/presentation/pages/notifications/no_notification_page.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// Notifications page showing in-app notification history.
class NotificationsNewPage extends ConsumerStatefulWidget {
  const NotificationsNewPage({super.key});

  @override
  ConsumerState<NotificationsNewPage> createState() =>
      _NotificationsNewPageState();
}

class _NotificationsNewPageState extends ConsumerState<NotificationsNewPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load notifications on page init
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).loadNotifications();
    });

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "BebasNeue",
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationsState state) {
    // The spinner only with nothing to show: the list on screen (saved or
    // from the last visit) stays while it is read again. It used to give
    // way to the spinner on every visit until the server answered.
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A1A2E),
        ),
      );
    }

    // Nothing saved and nothing fetched. Offline this is the offline state,
    // which reads the list again by itself when the network is back.
    if (state.error != null && state.notifications.isEmpty) {
      return ErrorView(
        message: state.error,
        onRetry: () =>
            ref.read(notificationsProvider.notifier).loadNotifications(),
      );
    }

    if (state.notifications.isEmpty) {
      return const NoNotificationPage();
    }

    // Group notifications by date
    final grouped = _groupNotifications(state.notifications);

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      color: const Color(0xFF1A1A2E),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: grouped.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == grouped.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            );
          }

          final group = grouped[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Text(
                  group.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'BebasNeue',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // Notification items
              ...group.notifications.map((notification) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildNotificationItem(notification),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final isUnread = notification.isUnread;

    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: ShapeDecoration(
          color: isUnread ? const Color(0xFFF8FFA0) : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar/Icon
            _buildNotificationAvatar(notification),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with rich text
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'DMSans',
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    notification.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w300,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Time
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationAvatar(NotificationModel notification) {
    // If there's a club logo, show it
    // Also show club logo for volunteer_added notifications if available
    if (notification.fromClub?.logo != null &&
        notification.fromClub!.logo!.isNotEmpty) {
      // Whole when it is not square (a wordmark), on a white disc.
      return ClubLogo(
        url: notification.fromClub!.logo!,
        size: 48,
        circle: true,
        fallback: _buildIconAvatar(notification),
      );
    }

    return _buildIconAvatar(notification);
  }

  Widget _buildIconAvatar(NotificationModel notification) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getColorForType(notification.type),
      ),
      child: Center(
        child: Text(
          notification.iconEmoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'certificate_generated':
        return const Color(0xFFFFE082); // Gold
      case 'event_checkin':
        return const Color(0xFFA5D6A7); // Green
      case 'new_event':
        return const Color(0xFFCE93D8); // Purple
      case 'nearby_event':
        return const Color(0xFF90CAF9); // Blue
      case 'volunteer_added':
        return const Color(0xFFFFCC80); // Orange
      case 'club_announcement':
        return const Color(0xFFEF9A9A); // Red
      case 'club_thread':
        return const Color(0xFFB8DFF2); // Blue, from the club page's palette
      case 'event_live_join':
      case 'event_live_started':
      case 'event_live_qa':
      case 'event_live_update':
        return const Color(0xFFA7F3D0); // Green, as the event page's live strip
      default:
        return Colors.grey[200]!;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read
    if (notification.isUnread) {
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }

    // Where it opens: the table a tapped push of its type uses too
    // (notification_routes.dart), with the row's event, else the push's
    // `event_id` in its data.
    final route = notification.route;
    if (route == null) return;
    // What the page can show before it has read anything itself.
    final eventName = notification.event?.name;
    final Map<String, dynamic>? extra;
    if (route.startsWith('/volunteer/scanner/')) {
      extra = {
        'eventName': eventName ?? 'Event',
        'clubName': notification.fromClub?.name ?? '',
      };
    } else if (route.endsWith('/people')) {
      extra = {'eventName': eventName ?? ''};
    } else {
      extra = null;
    }
    context.push(route, extra: extra);
  }

  List<_NotificationGroup> _groupNotifications(
      List<NotificationModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final List<NotificationModel> todayList = [];
    final List<NotificationModel> yesterdayList = [];
    final List<NotificationModel> thisWeekList = [];
    final List<NotificationModel> earlierList = [];

    for (final n in notifications) {
      // The phone's day, not UTC's: a line from 00:30 in India was filed
      // under "Yesterday".
      final at = n.createdAt.toLocal();
      final date = DateTime(at.year, at.month, at.day);

      if (date == today) {
        todayList.add(n);
      } else if (date == yesterday) {
        yesterdayList.add(n);
      } else if (date.isAfter(weekAgo)) {
        thisWeekList.add(n);
      } else {
        earlierList.add(n);
      }
    }

    final groups = <_NotificationGroup>[];

    if (todayList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'Today', notifications: todayList));
    }
    if (yesterdayList.isNotEmpty) {
      groups.add(
          _NotificationGroup(title: 'Yesterday', notifications: yesterdayList));
    }
    if (thisWeekList.isNotEmpty) {
      groups.add(
          _NotificationGroup(title: 'This Week', notifications: thisWeekList));
    }
    if (earlierList.isNotEmpty) {
      groups.add(
          _NotificationGroup(title: 'Earlier', notifications: earlierList));
    }

    return groups;
  }
}

class _NotificationGroup {
  final String title;
  final List<NotificationModel> notifications;

  _NotificationGroup({required this.title, required this.notifications});
}
