import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';

/// Provider for the profile remote data source.
final profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRemoteDataSourceImpl(dio);
});

/// Abstract interface for remote profile operations.
abstract class ProfileRemoteDataSource {
  /// Get current user's profile.
  Future<UserProfileModel> getMyProfile();

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

  ProfileRemoteDataSourceImpl(this._dio);

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
    final response = await _dio.get('/user/profile/me');
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfileModel> updateProfile(UpdateProfileRequest request) async {
    // POST /user/profile/update -- there is no PUT /user/profile.
    final response = await _dio.post(
      '/user/profile/update',
      data: request.toJson(),
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfileModel> createProfile(CreateProfileRequest request) async {
    final response = await _dio.post(
      '/user/profile/create',
      data: request.toJson(),
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
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
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<InterestModel>> getInterests() async {
    final response = await _dio.get('/interests/list');
    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserProfileModel> updateInterests(List<int> interestIds) async {
    final response = await _dio.post(
      '/user/interests/select',
      data: {'interest_ids': interestIds},
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }
}
