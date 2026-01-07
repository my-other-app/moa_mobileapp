import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:myotherapp/features/profile/domain/entities/profile_entity.dart';
import 'package:myotherapp/features/profile/domain/repositories/profile_repository.dart';

/// State for user profile.
class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isProfileComplete => profile?.isProfileComplete ?? false;
  bool get hasProfile => profile != null;
}

/// Provider for profile state management.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});

/// Notifier for profile operations.
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(const ProfileState());

  /// Load the current user's profile.
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getMyProfile();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (profile) {
        state = state.copyWith(
          isLoading: false,
          profile: profile,
        );
      },
    );
  }

  /// Update the user's profile.
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? whatsapp,
    int? organizationId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateProfile(
      fullName: fullName,
      phone: phone,
      whatsapp: whatsapp,
      organizationId: organizationId,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (profile) {
        state = state.copyWith(
          isLoading: false,
          profile: profile,
        );
        return true;
      },
    );
  }

  /// Create initial profile during onboarding.
  Future<bool> createProfile({
    required String fullName,
    required String whatsapp,
    required int organizationId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.createProfile(
      fullName: fullName,
      whatsapp: whatsapp,
      organizationId: organizationId,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (profile) {
        state = state.copyWith(
          isLoading: false,
          profile: profile,
        );
        return true;
      },
    );
  }

  /// Update user's avatar.
  Future<bool> updateAvatar(int avatarId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateAvatar(avatarId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (profile) {
        state = state.copyWith(
          isLoading: false,
          profile: profile,
        );
        return true;
      },
    );
  }

  /// Update user's interests.
  Future<bool> updateInterests(List<int> interestIds) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateInterests(interestIds);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (profile) {
        state = state.copyWith(
          isLoading: false,
          profile: profile,
        );
        return true;
      },
    );
  }

  /// Clear profile (on logout).
  void clearProfile() {
    state = const ProfileState();
  }
}

/// Provider for available organizations.
final organizationsProvider = FutureProvider<List<Organization>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final result = await repository.getOrganizations();
  return result.fold(
    (failure) {
      debugPrint('Failed to load organizations: ${failure.message}');
      return [];
    },
    (orgs) => orgs,
  );
});

/// Provider for available avatars.
final avatarsProvider = FutureProvider<List<Avatar>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final result = await repository.getAvatars();
  return result.fold(
    (failure) {
      debugPrint('Failed to load avatars: ${failure.message}');
      return [];
    },
    (avatars) => avatars,
  );
});

/// Provider for available interests.
final interestsProvider = FutureProvider<List<Interest>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final result = await repository.getInterests();
  return result.fold(
    (failure) {
      debugPrint('Failed to load interests: ${failure.message}');
      return [];
    },
    (interests) => interests,
  );
});
