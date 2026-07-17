import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

/// Repository interface for user profile operations.
abstract class ProfileRepository {
  /// Get the current user's profile.
  Future<Result<UserProfile>> getMyProfile();

  /// Update the user's profile.
  Future<Result<UserProfile>> updateProfile({
    String? fullName,
    String? phone,
    String? whatsapp,
    int? organizationId,
  });

  /// Create initial user profile (during onboarding).
  Future<Result<UserProfile>> createProfile({
    required String fullName,
    required String whatsapp,
    required int organizationId,
  });

  /// Get list of available organizations.
  Future<Result<List<Organization>>> getOrganizations();

  /// Get list of available avatars.
  Future<Result<List<Avatar>>> getAvatars();

  /// Update user's avatar.
  Future<Result<UserProfile>> updateAvatar(int avatarId);

  /// Get list of available interests.
  Future<Result<List<Interest>>> getInterests();

  /// Update user's selected interests.
  Future<Result<UserProfile>> updateInterests(List<int> interestIds);
}
