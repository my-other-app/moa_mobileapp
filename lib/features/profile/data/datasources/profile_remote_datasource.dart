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

  @override
  Future<UserProfileModel> getMyProfile() async {
    final response = await _dio.get('/user/profile/me');
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfileModel> updateProfile(UpdateProfileRequest request) async {
    final response = await _dio.put(
      '/user/profile',
      data: request.toJson(),
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfileModel> createProfile(CreateProfileRequest request) async {
    final response = await _dio.post(
      '/user/profile',
      data: request.toJson(),
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<OrganizationModel>> getOrganizations() async {
    final response = await _dio.get('/organizations');
    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((e) => OrganizationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AvatarModel>> getAvatars() async {
    final response = await _dio.get('/avatars');
    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((e) => AvatarModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserProfileModel> updateAvatar(int avatarId) async {
    final response = await _dio.put(
      '/user/avatar',
      data: {'avatar_id': avatarId},
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<InterestModel>> getInterests() async {
    final response = await _dio.get('/interests');
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
