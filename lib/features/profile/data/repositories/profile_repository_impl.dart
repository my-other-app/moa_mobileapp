import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';

/// Provider for the profile repository.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Implementation of profile repository.
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<UserProfile>> getMyProfile() async {
    try {
      final response = await remoteDataSource.getMyProfile();
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('ProfileRepository.getMyProfile error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<UserProfile>> updateProfile({
    String? fullName,
    String? phone,
    String? whatsapp,
    int? organizationId,
  }) async {
    try {
      final request = UpdateProfileRequest(
        fullName: fullName,
        phone: phone,
        whatsapp: whatsapp,
        organizationId: organizationId,
      );
      final response = await remoteDataSource.updateProfile(request);
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('ProfileRepository.updateProfile error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<UserProfile>> createProfile({
    required String fullName,
    required String whatsapp,
    required int organizationId,
  }) async {
    try {
      final request = CreateProfileRequest(
        fullName: fullName,
        whatsapp: whatsapp,
        organizationId: organizationId,
      );
      final response = await remoteDataSource.createProfile(request);
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('ProfileRepository.createProfile error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<Organization>>> getOrganizations() async {
    try {
      final response = await remoteDataSource.getOrganizations();
      return Either.right(response.map((e) => e.toEntity()).toList());
    } catch (e) {
      debugPrint('ProfileRepository.getOrganizations error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<Avatar>>> getAvatars() async {
    try {
      final response = await remoteDataSource.getAvatars();
      return Either.right(response.map((e) => e.toEntity()).toList());
    } catch (e) {
      debugPrint('ProfileRepository.getAvatars error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<UserProfile>> updateAvatar(int avatarId) async {
    try {
      final response = await remoteDataSource.updateAvatar(avatarId);
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('ProfileRepository.updateAvatar error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<Interest>>> getInterests() async {
    try {
      final response = await remoteDataSource.getInterests();
      return Either.right(response.map((e) => e.toEntity()).toList());
    } catch (e) {
      debugPrint('ProfileRepository.getInterests error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<UserProfile>> updateInterests(List<int> interestIds) async {
    try {
      final response = await remoteDataSource.updateInterests(interestIds);
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('ProfileRepository.updateInterests error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }
}
