import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';

/// Provider for the profile remote data source.
final profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRemoteDataSourceImpl(dio, cache: ref.watch(apiCacheProvider));
});

/// Abstract interface for remote profile operations.
abstract class ProfileRemoteDataSource {
  /// Get current user's profile.
  Future<UserProfileModel> getMyProfile();

  /// The profile as last saved on this phone, or null. No network.
  Future<UserProfileModel?> getSavedProfile();

  /// Update user's profile.
  Future<UserProfileModel> updateProfile(UpdateProfileRequest request);

  /// Create initial profile.
  Future<UserProfileModel> createProfile(CreateProfileRequest request);

  /// Get available organizations.
  Future<List<OrganizationModel>> getOrganizations();

  /// Get available avatars.
  Future<List<AvatarModel>> getAvatars();

  /// Update user's avatar.
  Future<UserProfileModel> updateAvatar(int avatarId);

  /// Get available interests.
  Future<List<InterestModel>> getInterests();

  /// Update user's interests.
  Future<UserProfileModel> updateInterests(List<int> interestIds);
}

/// Implementation of profile remote data source.
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  final ApiCache? _cache;

  ProfileRemoteDataSourceImpl(this._dio, {ApiCache? cache}) : _cache = cache;

  static const _me = '/user/profile/me';

  /// A body that is not an object reads as an empty one: the model fills
  /// in its defaults rather than the cast throwing.
  static Map<String, dynamic> _object(Object? body) =>
      body is Map<String, dynamic> ? body : const <String, dynamic>{};

  /// Pull a list out of a body that may be a bare array or a paginated
  /// envelope. The server uses `items` for the paginated ones; reading the
  /// body as a list returned nothing, with no error, when it was not one.
  static List<dynamic> _listFrom(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      return (body['items'] as List<dynamic>?) ?? const [];
    }
    return const [];
  }

  @override
  Future<UserProfileModel> getMyProfile() async {
    final response = await _dio.get(
      _me,
      // The person's own details: saved encrypted, and never pruned to
      // make room -- the Profile tab and every form lean on it offline.
      options: Options(extra: CachePolicy.personalKept.extra),
    );
    return UserProfileModel.fromJson(_object(response.data));
  }

  @override
  Future<UserProfileModel?> getSavedProfile() async {
    final data = await (_cache ?? ApiCache.instance)
        .savedAnswer(_dio, _me, scope: CacheScope.personal);
    return data is Map<String, dynamic> ? UserProfileModel.fromJson(data) : null;
  }

  @override
  Future<UserProfileModel> updateProfile(UpdateProfileRequest request) async {
    // POST /user/profile/update -- there is no PUT /user/profile.
    final response = await _dio.post(
      '/user/profile/update',
      data: request.toJson(),
    );
    return UserProfileModel.fromJson(_object(response.data));
  }

  @override
  Future<UserProfileModel> createProfile(CreateProfileRequest request) async {
    final response = await _dio.post(
      '/user/profile/create',
      data: request.toJson(),
    );
    return UserProfileModel.fromJson(_object(response.data));
  }

  @override
  Future<List<OrganizationModel>> getOrganizations() async {
    final response = await _dio.get('/orgs/list');
    // Paginated, so the list is under `items` rather than being the body.
    final List<dynamic> data = _listFrom(response.data);
    return data
        .map((e) => OrganizationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AvatarModel>> getAvatars() async {
    final response = await _dio.get('/user/avatar/list');
    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((e) => AvatarModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserProfileModel> updateAvatar(int avatarId) async {
    // POST /user/avatar/select -- there is no PUT /user/avatar.
    final response = await _dio.post(
      '/user/avatar/select',
      data: {'avatar_id': avatarId},
    );
    return UserProfileModel.fromJson(_object(response.data));
  }

  /// Every interest, flattened out of its topic.
  ///
  /// `/interests/list` is a list of topics (interest categories), each with
  /// its `interests`. It used to be read as a list of interests, which gave
  /// back the topics themselves: one "interest" called "arts" with the
  /// category's id, and none of the real ones.
  @override
  Future<List<InterestModel>> getInterests() async {
    final response = await _dio.get('/interests/list');
    final List<dynamic> data = _listFrom(response.data);
    return [
      for (final topic in data.whereType<Map<String, dynamic>>())
        if (topic['interests'] is List)
          for (final e in (topic['interests'] as List)
              .whereType<Map<String, dynamic>>())
            InterestModel.fromJson(e,
                categoryId: (topic['id'] as num?)?.toInt())
        else
          // Not a topic: an interest listed bare.
          InterestModel.fromJson(topic),
    ];
  }

  @override
  Future<UserProfileModel> updateInterests(List<int> interestIds) async {
    final response = await _dio.post(
      '/user/interests/select',
      data: {'interest_ids': interestIds},
    );
    return UserProfileModel.fromJson(_object(response.data));
  }
}
