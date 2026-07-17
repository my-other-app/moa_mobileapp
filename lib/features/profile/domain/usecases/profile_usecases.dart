import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/usecases/usecase.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';

/// Use case for getting the current user's profile.
class GetMyProfileUseCase extends NoParamsUseCase<UserProfile> {
  final ProfileRepository repository;

  GetMyProfileUseCase(this.repository);

  @override
  Future<Result<UserProfile>> call() {
    return repository.getMyProfile();
  }
}

/// Parameters for creating a user profile.
class CreateProfileParams {
  final String fullName;
  final String whatsapp;
  final int organizationId;

  const CreateProfileParams({
    required this.fullName,
    required this.whatsapp,
    required this.organizationId,
  });
}

/// Use case for creating a user profile during onboarding.
class CreateProfileUseCase extends UseCase<UserProfile, CreateProfileParams> {
  final ProfileRepository repository;

  CreateProfileUseCase(this.repository);

  @override
  Future<Result<UserProfile>> call(CreateProfileParams params) {
    return repository.createProfile(
      fullName: params.fullName,
      whatsapp: params.whatsapp,
      organizationId: params.organizationId,
    );
  }
}

/// Parameters for updating a user profile.
class UpdateProfileParams {
  final String? fullName;
  final String? phone;
  final String? whatsapp;
  final int? organizationId;

  const UpdateProfileParams({
    this.fullName,
    this.phone,
    this.whatsapp,
    this.organizationId,
  });
}

/// Use case for updating the user's profile.
class UpdateProfileUseCase extends UseCase<UserProfile, UpdateProfileParams> {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  @override
  Future<Result<UserProfile>> call(UpdateProfileParams params) {
    return repository.updateProfile(
      fullName: params.fullName,
      phone: params.phone,
      whatsapp: params.whatsapp,
      organizationId: params.organizationId,
    );
  }
}

/// Use case for getting available organizations.
class GetOrganizationsUseCase extends NoParamsUseCase<List<Organization>> {
  final ProfileRepository repository;

  GetOrganizationsUseCase(this.repository);

  @override
  Future<Result<List<Organization>>> call() {
    return repository.getOrganizations();
  }
}

/// Use case for getting available avatars.
class GetAvatarsUseCase extends NoParamsUseCase<List<Avatar>> {
  final ProfileRepository repository;

  GetAvatarsUseCase(this.repository);

  @override
  Future<Result<List<Avatar>>> call() {
    return repository.getAvatars();
  }
}

/// Use case for updating the user's avatar.
class UpdateAvatarUseCase extends UseCase<UserProfile, int> {
  final ProfileRepository repository;

  UpdateAvatarUseCase(this.repository);

  @override
  Future<Result<UserProfile>> call(int avatarId) {
    return repository.updateAvatar(avatarId);
  }
}

/// Use case for getting available interests.
class GetInterestsUseCase extends NoParamsUseCase<List<Interest>> {
  final ProfileRepository repository;

  GetInterestsUseCase(this.repository);

  @override
  Future<Result<List<Interest>>> call() {
    return repository.getInterests();
  }
}

/// Use case for updating user's interests.
class UpdateInterestsUseCase extends UseCase<UserProfile, List<int>> {
  final ProfileRepository repository;

  UpdateInterestsUseCase(this.repository);

  @override
  Future<Result<UserProfile>> call(List<int> interestIds) {
    return repository.updateInterests(interestIds);
  }
}
