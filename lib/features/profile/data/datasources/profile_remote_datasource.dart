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

  /// The preset avatars an admin keeps. Saved for everyone (the same
  /// list for all), so the picker opens on them at once next time.
  Future<List<AvatarModel>> getAvatars();

  /// The avatars as last saved on this phone, or null. No network.
  Future<List<AvatarModel>?> getSavedAvatars();

  /// Make [avatarId] their picture: `POST /user/avatar/select`, which
  /// answers with the avatar (not the profile). The saved profile is
  /// brought in line, so the change shows offline and after a restart.
  Future<AvatarModel> selectAvatar(int avatarId);

  /// Upload the photo at [path] as their picture:
  /// `PUT /user/profile/update-picture` (multipart, `profile_picture`),
  /// which answers with the new photo's sizes. The saved profile is
  /// brought in line.
  Future<ImageUrlsModel?> uploadPicture(String path);

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

  static const _avatars = '/user/avatar/list';

  static List<AvatarModel> _avatarsFrom(Object? body) => [
        for (final item in _listFrom(body).whereType<Map<String, dynamic>>())
          AvatarModel.fromJson(item),
      ];

  @override
  Future<List<AvatarModel>> getAvatars() async {
    final response = await _dio.get(
      _avatars,
      // The same pictures for everyone: saved as a shared answer.
      options: Options(extra: CachePolicy.shared.extra),
    );
    return _avatarsFrom(response.data);
  }

  @override
  Future<List<AvatarModel>?> getSavedAvatars() async {
    final data = await (_cache ?? ApiCache.instance).savedAnswer(_dio, _avatars);
    return data == null ? null : _avatarsFrom(data);
  }

  @override
  Future<AvatarModel> selectAvatar(int avatarId) async {
    // POST /user/avatar/select -- there is no PUT /user/avatar. It answers
    // with the avatar; it was read as a profile, which made one with the
    // avatar's id and name.
    final response = await _dio.post(
      '/user/avatar/select',
      data: {'avatar_id': avatarId},
    );
    final avatar = AvatarModel.fromJson(_object(response.data));
    await _patchSavedProfile((profile) {
      profile['avatar'] = avatar.toJson();
      profile['avatar_id'] = avatar.id;
      profile['profile_pic'] = null;
    });
    return avatar;
  }

  @override
  Future<ImageUrlsModel?> uploadPicture(String path) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    final form = FormData.fromMap({
      'profile_picture': await MultipartFile.fromFile(
        path,
        filename: name,
        // The server refuses anything not sent as image/*; Dio would send
        // application/octet-stream.
        contentType: _imageTypeOf(name),
      ),
    });
    final response = await _dio.put('/user/profile/update-picture', data: form);
    final body = response.data;
    if (body is! Map<String, dynamic>) return null;
    final urls = ImageUrlsModel.fromJson(body);
    if (urls.toEntity().urlFor() == null) return null;
    await _patchSavedProfile((profile) => profile['profile_pic'] = body);
    return urls;
  }

  static DioMediaType _imageTypeOf(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'png' => DioMediaType('image', 'png'),
      'webp' => DioMediaType('image', 'webp'),
      'gif' => DioMediaType('image', 'gif'),
      'heic' || 'heif' => DioMediaType('image', ext),
      _ => DioMediaType('image', 'jpeg'),
    };
  }

  /// Change the saved copy of `GET /user/profile/me` in place with [edit]
  /// (given its `profile` object): what the server just confirmed, so the
  /// Profile tab shows it offline and straight after a restart. Nothing
  /// saved, nothing to change; never throws.
  Future<void> _patchSavedProfile(
      void Function(Map<String, dynamic> profile) edit) async {
    try {
      final cache = _cache ?? ApiCache.instance;
      final saved = await cache.savedAnswer(_dio, _me, scope: CacheScope.personal);
      if (saved is! Map) return;
      final body = Map<String, dynamic>.from(saved);
      final profile = body['profile'] is Map
          ? Map<String, dynamic>.from(body['profile'] as Map)
          : <String, dynamic>{};
      edit(profile);
      body['profile'] = profile;
      await cache.saveAnswer(_dio, _me, body,
          scope: CacheScope.personal, keep: true);
    } catch (_) {
      // A saved copy is a convenience: the next read of the profile
      // replaces it anyway.
    }
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
