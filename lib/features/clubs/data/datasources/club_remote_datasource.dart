import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/clubs/data/models/club_models.dart';

/// Provider for the club remote data source.
final clubRemoteDataSourceProvider = Provider<ClubRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ClubRemoteDataSourceImpl(dio);
});

/// Abstract interface for remote club operations.
///
/// Every path here is checked against `app/api/clubs/router.py`. The previous
/// version of this file was not: eight of its nine calls addressed routes the
/// server has never had (`/clubs/pinned`, `/clubs/{id}`, `DELETE
/// /clubs/{id}/follow`, ...), the ninth sent `page` where the server reads
/// `offset`, and all of them unpacked `results` from an envelope whose list
/// is called `items`. Nothing noticed, because no screen had been moved onto
/// this layer yet -- the pages still call APIService directly with the
/// correct paths. Whoever migrated the first page would have found clubs
/// silently empty.
abstract class ClubRemoteDataSource {
  /// One page of clubs, with whichever filters apply.
  ///
  /// `GET /clubs/list` is the server's only club listing; following, pinned
  /// and search are filters on it rather than endpoints of their own.
  Future<List<ClubModel>> getClubs({
    int? page,
    int? limit,
    String? search,
    int? organizationId,
    List<int>? interestIds,
    bool? isFollowing,
    bool? isPinned,
    bool? isHidden,
  });

  /// Get followed clubs.
  Future<List<ClubModel>> getFollowingClubs({int? page, int? limit});

  /// Get pinned clubs.
  Future<List<ClubModel>> getPinnedClubs();

  /// Get club details.
  Future<ClubModel> getClubDetails(int clubId);

  /// Follow a club.
  Future<void> followClub(int clubId);

  /// Unfollow a club.
  Future<void> unfollowClub(int clubId);

  /// Flip the club's pinned state and return what it became.
  ///
  /// The server endpoint is a toggle, so there is no way to say "pin this"
  /// and no way to be sure which way it went without being told. The new
  /// state is read back from the response rather than guessed by flipping a
  /// local boolean, which is wrong whenever the local one is stale -- two
  /// taps, or a pin set on another device, and "pin" unpins.
  Future<bool> togglePin(int clubId);

  /// Flip whether this club's events are hidden, and return what it became.
  Future<bool> toggleHide(int clubId);

  /// Search clubs.
  Future<List<ClubModel>> searchClubs(String query);
}

/// Implementation of club remote data source.
class ClubRemoteDataSourceImpl implements ClubRemoteDataSource {
  final Dio _dio;

  ClubRemoteDataSourceImpl(this._dio);

  /// Default page size, matching the server's own default for `limit`.
  static const _defaultLimit = 10;

  @override
  Future<List<ClubModel>> getClubs({
    int? page,
    int? limit,
    String? search,
    int? organizationId,
    List<int>? interestIds,
    bool? isFollowing,
    bool? isPinned,
    bool? isHidden,
  }) async {
    final size = limit ?? _defaultLimit;
    final queryParams = <String, dynamic>{
      'limit': size,
      // The server paginates on offset, not page. `page` is kept in the
      // domain because that is how the callers count, and converted here.
      'offset': page == null ? 0 : (page - 1).clamp(0, 1 << 30) * size,
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (organizationId != null) queryParams['org_id'] = organizationId;
    if (interestIds != null && interestIds.isNotEmpty) {
      queryParams['interest_ids'] = interestIds.join(',');
    }
    if (isFollowing != null) queryParams['is_following'] = isFollowing;
    if (isPinned != null) queryParams['is_pinned'] = isPinned;
    if (isHidden != null) queryParams['is_hidden'] = isHidden;

    final response = await _dio.get<Map<String, dynamic>>(
      '/clubs/list',
      queryParameters: queryParams,
    );
    return _clubsFrom(response.data);
  }

  @override
  Future<List<ClubModel>> getFollowingClubs({int? page, int? limit}) {
    return getClubs(page: page, limit: limit, isFollowing: true);
  }

  @override
  Future<List<ClubModel>> getPinnedClubs() {
    return getClubs(isPinned: true);
  }

  @override
  Future<ClubModel> getClubDetails(int clubId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/clubs/info/$clubId');
    return ClubModel.fromJson(response.data ?? const <String, dynamic>{});
  }

  @override
  Future<void> followClub(int clubId) async {
    await _dio.post<dynamic>('/clubs/follow/$clubId');
  }

  @override
  Future<void> unfollowClub(int clubId) async {
    // POST, not DELETE: the server has a dedicated unfollow route rather
    // than treating the follow as a resource.
    await _dio.post<dynamic>('/clubs/unfollow/$clubId');
  }

  @override
  Future<bool> togglePin(int clubId) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/clubs/pin/$clubId');
    return (response.data?['is_pinned'] as bool?) ?? false;
  }

  @override
  Future<bool> toggleHide(int clubId) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/clubs/hide/$clubId');
    return (response.data?['is_hidden'] as bool?) ?? false;
  }

  @override
  Future<List<ClubModel>> searchClubs(String query) {
    return getClubs(search: query);
  }

  /// Unpack the paginated envelope.
  ///
  /// The list is under `items` -- `PaginatedResponse` in
  /// `app/core/response/pagination.py`. Reading `results` instead returned
  /// the empty fallback on every call, with no error to show for it.
  List<ClubModel> _clubsFrom(Map<String, dynamic>? body) {
    final items = (body?['items'] as List<dynamic>?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ClubModel.fromJson)
        .toList();
  }
}
