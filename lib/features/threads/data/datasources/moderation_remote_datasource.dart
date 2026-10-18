import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/threads/data/models/moderation_models.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';

/// Provider for the moderation remote data source.
final moderationRemoteDataSourceProvider =
    Provider<ModerationRemoteDataSource>((ref) {
  return ModerationRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// Remote calls for reports and blocks.
///
/// Paths are relative to the app's base URL, which already ends in /api/v1.
abstract class ModerationRemoteDataSource {
  /// `POST /reports` with `{target_type, target_id, reason, note?}`.
  Future<void> report(ReportTarget target, ReportReason reason, {String? note});

  /// `POST /user/blocks` with `{user_id}`.
  Future<void> block(int userId);

  /// `DELETE /user/blocks/{user_id}`.
  Future<void> unblock(int userId);

  /// `GET /user/blocks` -- `[{user_id, name, avatar}]`.
  Future<List<BlockedUserModel>> getBlockedUsers();
}

/// Implementation of [ModerationRemoteDataSource] over the app's Dio.
class ModerationRemoteDataSourceImpl implements ModerationRemoteDataSource {
  final Dio _dio;

  ModerationRemoteDataSourceImpl(this._dio);

  @override
  Future<void> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) async {
    await _dio.post<dynamic>(
      '/reports',
      data: reportRequestBody(target, reason, note: note),
    );
  }

  @override
  Future<void> block(int userId) async {
    await _dio.post<dynamic>('/user/blocks', data: {'user_id': userId});
  }

  @override
  Future<void> unblock(int userId) async {
    await _dio.delete<dynamic>('/user/blocks/$userId');
  }

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    final response = await _dio.get<dynamic>('/user/blocks');
    final data = response.data;
    // A bare list, as the route returns; the paginated envelope too, in case
    // it grows one. Anything else reads as nobody blocked.
    final items = data is List
        ? data
        : (data is Map && data['items'] is List ? data['items'] as List : []);
    return items
        .whereType<Map>()
        .map((e) => BlockedUserModel.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.userId != null)
        .toList();
  }
}
