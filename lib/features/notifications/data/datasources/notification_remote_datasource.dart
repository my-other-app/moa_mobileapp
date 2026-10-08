import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';

/// Provider for the notification remote data source.
final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationRemoteDataSourceImpl(dio);
});

/// One page of notifications, with the server's own total.
///
/// The total is carried rather than inferred from the page length: a page
/// that happens to come back short is not the same as the end of the list,
/// and treating it as such stops pagination one page early.
class NotificationPage {
  final List<NotificationModel> items;
  final int total;

  const NotificationPage({required this.items, required this.total});
}

/// Abstract interface for remote notification operations.
abstract class NotificationRemoteDataSource {
  /// Fetch one page of notifications.
  Future<NotificationPage> fetchList({required int limit, required int offset});

  /// How many are unread.
  Future<int> unreadCount();

  /// Mark one as read.
  Future<void> markAsRead(String notificationId);

  /// Mark every notification as read.
  Future<void> markAllAsRead();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Dio _dio;

  NotificationRemoteDataSourceImpl(this._dio);

  @override
  Future<NotificationPage> fetchList({
    required int limit,
    required int offset,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications/fetch-list',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    final data = response.data ?? const <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];
    return NotificationPage(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList(),
      // `total` absent means the server did not say; falling back to the
      // page length is the closest honest answer, not zero.
      total: (data['total'] as int?) ?? rawItems.length,
    );
  }

  @override
  Future<int> unreadCount() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return (response.data?['count'] as int?) ?? 0;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _dio.post<dynamic>('/notifications/read/$notificationId');
  }

  @override
  Future<void> markAllAsRead() async {
    await _dio.post<dynamic>('/notifications/read-all');
  }
}
