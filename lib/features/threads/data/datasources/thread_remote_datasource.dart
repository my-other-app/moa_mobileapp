import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/threads/data/models/thread_models.dart';

/// Provider for the threads remote data source.
final threadRemoteDataSourceProvider = Provider<ThreadRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ThreadRemoteDataSourceImpl(dio, cache: ref.watch(apiCacheProvider));
});

/// Remote calls for club Threads.
///
/// Every path is checked against the backend's `app/api/threads/router.py`
/// (`public_router`). The reads work signed out; the app's Dio sends the
/// user's token whenever there is one, which is what lets the server answer
/// `liked` and `voted_option_id` for this person.
abstract class ThreadRemoteDataSource {
  /// `GET /clubs/{club_id}/threads` -- a club's posts, pinned first.
  Future<ThreadPageModel> getClubThreads(
    int clubId, {
    required int offset,
    required int limit,
  });

  /// `GET /threads/feed` -- posts from the clubs this person follows,
  /// newest first; [after] is the `next_cursor` of the page before. Needs a
  /// session. The first page is kept on the phone (encrypted: who you
  /// follow is yours).
  Future<ThreadPageModel> getFollowingFeed({String? after, required int limit});

  /// The first page of the feed as last kept on this phone, or null.
  Future<ThreadPageModel?> savedFollowingFeed({required int limit});

  /// `GET /threads/{thread_id}` -- one post; 404 once it is removed.
  Future<ThreadModel> getThread(String threadId);

  /// `POST /threads/{thread_id}/like` -- a toggle.
  Future<LikeResultModel> toggleLike(String threadId);

  /// `POST /threads/{thread_id}/vote` with `{option_id}`.
  Future<PollModel> vote(String threadId, String optionId);

  /// `GET /threads/{thread_id}/comments`.
  Future<List<ThreadCommentModel>> getComments(String threadId);

  /// `POST /threads/{thread_id}/comments` with `{body}`.
  Future<ThreadCommentModel> addComment(String threadId, String body);

  /// `DELETE /threads/{thread_id}/comments/{comment_id}` -- own comments only.
  Future<void> deleteComment(String threadId, String commentId);
}

/// Implementation of [ThreadRemoteDataSource] over the app's Dio.
class ThreadRemoteDataSourceImpl implements ThreadRemoteDataSource {
  final Dio _dio;
  final ApiCache? _cache;

  ThreadRemoteDataSourceImpl(this._dio, {ApiCache? cache}) : _cache = cache;

  static const _feedPath = '/threads/feed';

  /// Ids come from notification payloads as well as from the server's own
  /// lists, so they are escaped rather than trusted to be path-safe.
  String _thread(String threadId) =>
      '/threads/${Uri.encodeComponent(threadId)}';

  @override
  Future<ThreadPageModel> getClubThreads(
    int clubId, {
    required int offset,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/clubs/$clubId/threads',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    return ThreadPageModel.fromJson(response.data);
  }

  @override
  Future<ThreadPageModel> getFollowingFeed({
    String? after,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _feedPath,
      queryParameters: {
        'limit': limit,
        if (after != null) 'after': after,
      },
      // Only the first page is worth keeping: it is what opens first.
      options:
          after == null ? Options(extra: CachePolicy.personal.extra) : null,
    );
    return ThreadPageModel.fromJson(response.data);
  }

  @override
  Future<ThreadPageModel?> savedFollowingFeed({required int limit}) async {
    final data = await (_cache ?? ApiCache.instance).savedAnswer(
      _dio,
      _feedPath,
      query: {'limit': limit},
      scope: CacheScope.personal,
    );
    return data is Map
        ? ThreadPageModel.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  @override
  Future<ThreadModel> getThread(String threadId) async {
    final response = await _dio.get<Map<String, dynamic>>(_thread(threadId));
    return ThreadModel.fromJson(response.data ?? const <String, dynamic>{});
  }

  @override
  Future<LikeResultModel> toggleLike(String threadId) async {
    final response =
        await _dio.post<Map<String, dynamic>>('${_thread(threadId)}/like');
    return LikeResultModel.fromJson(response.data);
  }

  @override
  Future<PollModel> vote(String threadId, String optionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${_thread(threadId)}/vote',
      data: {'option_id': optionId},
    );
    return PollModel.fromJson(response.data);
  }

  @override
  Future<List<ThreadCommentModel>> getComments(String threadId) async {
    final response = await _dio.get<dynamic>('${_thread(threadId)}/comments');
    final data = response.data;
    // A bare list, as `list[CommentOut]` serialises; anything else is read
    // as no comments rather than thrown at the page.
    final items = data is List ? data : const [];
    return items
        .whereType<Map>()
        .map((e) => ThreadCommentModel.fromJson(Map<String, dynamic>.from(e)))
        // A comment without an id could never be deleted or keyed.
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  @override
  Future<ThreadCommentModel> addComment(String threadId, String body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${_thread(threadId)}/comments',
      data: {'body': body},
    );
    return ThreadCommentModel.fromJson(
        response.data ?? const <String, dynamic>{});
  }

  @override
  Future<void> deleteComment(String threadId, String commentId) async {
    await _dio.delete<dynamic>(
      '${_thread(threadId)}/comments/${Uri.encodeComponent(commentId)}',
    );
  }
}
