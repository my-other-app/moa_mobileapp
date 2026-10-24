import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

/// Repository interface for user profile operations.
abstract class ProfileRepository {
  /// Get the current user's profile.
  Future<Result<UserProfile>> getMyProfile();

  /// The profile as last saved on this phone, or null. No network.
  Future<UserProfile?> getSavedProfile();

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

  /// The avatars as last saved on this phone, or null. No network, never
  /// fails.
  Future<List<Avatar>?> getSavedAvatars();

  /// Make a preset avatar their picture (it replaces an uploaded photo).
  Future<Result<Avatar>> selectAvatar(int avatarId);

  /// Upload the photo at [path] as their picture; its sizes, or null when
  /// the server did not say them (read the profile again for them).
  Future<Result<ImageUrls?>> uploadPicture(String path);

  /// Update user's selected interests.
  Future<Result<UserProfile>> updateInterests(List<int> interestIds);
}
