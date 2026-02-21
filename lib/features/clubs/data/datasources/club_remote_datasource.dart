import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/network/dio_client.dart';
import 'package:myotherapp/features/clubs/data/models/club_models.dart';

/// Provider for the club remote data source.
final clubRemoteDataSourceProvider = Provider<ClubRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ClubRemoteDataSourceImpl(dio);
});

/// Abstract interface for remote club operations.
abstract class ClubRemoteDataSource {
  /// Get list of clubs.
  Future<List<ClubModel>> getClubs({
    int? page,
    int? limit,
    String? search,
    int? organizationId,
    List<int>? interestIds,
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

  /// Pin a club.
  Future<void> pinClub(int clubId);

  /// Unpin a club.
  Future<void> unpinClub(int clubId);

  /// Search clubs.
  Future<List<ClubModel>> searchClubs(String query);
}

/// Implementation of club remote data source.
class ClubRemoteDataSourceImpl implements ClubRemoteDataSource {
  final Dio _dio;

  ClubRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ClubModel>> getClubs({
    int? page,
    int? limit,
    String? search,
    int? organizationId,
    List<int>? interestIds,
  }) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (organizationId != null) queryParams['org_id'] = organizationId;
    if (interestIds != null && interestIds.isNotEmpty) {
      queryParams['interest_ids'] = interestIds.join(',');
    }

    final response =
        await _dio.get('/clubs/list', queryParameters: queryParams);
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ClubModel>> getFollowingClubs({int? page, int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;

    final response =
        await _dio.get('/clubs/following', queryParameters: queryParams);
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ClubModel>> getPinnedClubs() async {
    final response = await _dio.get('/clubs/pinned');
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ClubModel> getClubDetails(int clubId) async {
    final response = await _dio.get('/clubs/$clubId');
    return ClubModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> followClub(int clubId) async {
    await _dio.post('/clubs/$clubId/follow');
  }

  @override
  Future<void> unfollowClub(int clubId) async {
    await _dio.delete('/clubs/$clubId/follow');
  }

  @override
  Future<void> pinClub(int clubId) async {
    await _dio.post('/clubs/$clubId/pin');
  }

  @override
  Future<void> unpinClub(int clubId) async {
    await _dio.delete('/clubs/$clubId/pin');
  }

  @override
  Future<List<ClubModel>> searchClubs(String query) async {
    final response =
        await _dio.get('/clubs/search', queryParameters: {'q': query});
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
