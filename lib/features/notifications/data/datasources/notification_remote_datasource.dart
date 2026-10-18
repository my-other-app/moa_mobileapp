import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
///
/// [nextCursor] is the server's keyset cursor for the page after this one,
/// when it gives one (taken from `next`): a page read from it costs the same
/// however far down it is, and does not shift when newer lines arrive.
class NotificationPage {
  final List<NotificationModel> items;
  final int total;
  final String? nextCursor;

  const NotificationPage({
    required this.items,
    required this.total,
    this.nextCursor,
  });
}

/// Abstract interface for remote notification operations.
abstract class NotificationRemoteDataSource {
  /// Fetch one page of notifications: after [cursor] when there is one,
  /// else past [offset].
  Future<NotificationPage> fetchList({
    required int limit,
    required int offset,
    String? cursor,
  });

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
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications/fetch-list',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (cursor != null) 'cursor': cursor,
      },
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
      nextCursor: cursorFromNext(data['next']),
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

/// The keyset cursor in a page's `next` link, or null when it has none (a
/// server that pages by offset only, or the last page).
@visibleForTesting
String? cursorFromNext(Object? next) {
  if (next is! String || next.isEmpty) return null;
  final cursor = Uri.tryParse(next)?.queryParameters['cursor'];
  return cursor == null || cursor.isEmpty ? null : cursor;
}
