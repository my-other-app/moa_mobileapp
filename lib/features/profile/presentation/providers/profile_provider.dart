import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';

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
///
/// Read again when the app comes back online, so a profile drawn from the
/// saved copy -- or one that could not load at all -- is brought up to date
/// without a visit to the Profile tab.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final notifier = ProfileNotifier(repository);
  ref.listen<int>(backOnlineProvider, (_, __) {
    if (ref.read(isAuthenticatedProvider)) notifier.loadProfile();
  });
  return notifier;
});

/// Notifier for profile operations.
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  /// Loads the profile as soon as anything asks for it.
  ///
  /// It used to wait for a screen to call loadProfile(), and only the
  /// profile screens, the login flow and onboarding ever did. Open the app
  /// with a stored token -- so no login flow runs -- go straight to an event
  /// and the registration form read a state nobody had filled: name, email
  /// and phone blank, with no error and nothing to retry. Visiting Profile
  /// ran its initState, which is why those fields appeared only after a trip
  /// to Settings and back.
  ///
  /// Riverpod builds a provider on first read, so loading here means "fetch
  /// when first needed" rather than "fetch at startup", and every consumer
  /// gets the same answer without having to know to ask.
  ProfileNotifier(this._repository) : super(const ProfileState()) {
    loadProfile();
  }

  /// Load the current user's profile.
  ///
  /// Reuses an in-flight request rather than starting a second one: several
  /// screens can mount at once, and each watching the provider must not mean
  /// another identical call.
  Future<void>? _inFlight;

  Future<void> loadProfile({bool force = false}) {
    if (_inFlight != null && !force) return _inFlight!;
    final request = _loadProfile();
    _inFlight = request.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    // The copy saved on this phone first, so every screen that shows the
    // name or fills a form has it at once -- and offline.
    if (state.profile == null) {
      UserProfile? saved;
      try {
        saved = await _repository.getSavedProfile();
      } catch (e) {
        debugPrint('ProfileNotifier: no saved profile: $e');
      }
      if (!mounted) return;
      if (saved != null && state.profile == null) {
        state = state.copyWith(profile: saved, isLoading: true);
      }
    }

    final result = await _repository.getMyProfile();
    if (!mounted) return;

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          // With a saved profile on screen, a failed refresh is not an
          // error to show: the offline strip says why it is not fresh.
          error: state.profile == null ? failure.message : null,
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

  /// "Show me in People Like You" as the server kept it, so every screen
  /// reading the profile agrees without a reload.
  void networkingVisibleSaved(bool visible) {
    final profile = state.profile;
    if (profile == null) return;
    state = state.copyWith(
        profile: profile.copyWith(networkingVisible: visible),
        error: state.error);
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
