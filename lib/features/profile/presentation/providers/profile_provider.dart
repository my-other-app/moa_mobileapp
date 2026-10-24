import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// State for user profile.
class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  /// The photo just taken or chosen, on this phone: drawn as their picture
  /// while it uploads, and under the uploaded one while that loads.
  final String? localPhoto;

  /// [localPhoto] is on its way to the server.
  final bool uploadingPhoto;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.localPhoto,
    this.uploadingPhoto = false,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    String? Function()? localPhoto,
    bool? uploadingPhoto,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      localPhoto: localPhoto != null ? localPhoto() : this.localPhoto,
      uploadingPhoto: uploadingPhoto ?? this.uploadingPhoto,
    );
  }

  bool get isProfileComplete => profile?.isProfileComplete ?? false;
}

/// Provider for profile state management.
///
/// Read again when the app comes back online, so a profile drawn from the
/// saved copy -- or one that could not load at all -- is brought up to date
/// without a visit to the Profile tab.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final notifier =
      ProfileNotifier(repository, evict: ref.watch(pictureEvictorProvider));
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
  ProfileNotifier(this._repository, {PictureEvictor? evict})
      : _evict = evict ?? evictPictures,
        super(const ProfileState()) {
    loadProfile();
  }

  final PictureEvictor _evict;

  /// Picture changes sent and not yet answered: a profile read meanwhile
  /// keeps the picture on screen rather than the one the server had
  /// before the change.
  int _changingPicture = 0;

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
        final shown = state.profile;
        state = state.copyWith(
          isLoading: false,
          profile: _changingPicture > 0 && shown != null
              ? profile.withPicture(avatar: shown.avatar, photo: shown.photo)
              : profile,
        );
      },
    );
  }

  /// Make a preset [avatar] their picture.
  ///
  /// Shown everywhere at once -- the profile header, Settings, their own
  /// comments -- then sent. Once the server has answered, the profile is
  /// read back and is what stays: it is the only sure word on what stuck.
  /// The server before the backend's feat/user-avatar saves the pick and
  /// *then* answers 500 (it reads the avatar back lazily, which an async
  /// session cannot), and keeps an uploaded photo in front of the avatar.
  /// Returns null when it stuck, else what to tell the person.
  Future<String?> chooseAvatar(Avatar avatar) async {
    final before = state.profile;
    if (before == null) return "Your profile hasn't loaded yet. Try again.";
    if (before.photo == null &&
        before.avatar?.id == avatar.id &&
        !state.uploadingPhoto) {
      return null;
    }
    _changingPicture++;
    state = state.copyWith(
      profile: before.withPicture(avatar: avatar, photo: null),
      localPhoto: () => null,
      uploadingPhoto: false,
      error: state.error,
    );
    final result = await _repository.selectAvatar(avatar.id);
    final failure = result.isLeft ? result.left : null;
    if (failure != null && !_mayHaveStuck(failure)) {
      _changingPicture--;
      if (mounted) _putBack(before);
      return pictureFailureMessage(failure);
    }
    final fresh = await _repository.getMyProfile();
    _changingPicture--;
    if (!mounted) return null;
    final server = fresh.isRight ? fresh.right : null;
    if (server == null) {
      // Not read back. A yes is taken at its word; anything else is put
      // back.
      if (failure == null) {
        _evictPhoto(before.photo);
        return null;
      }
      _putBack(before);
      return pictureFailureMessage(failure);
    }
    _showFromServer(server);
    if (server.avatar?.id != avatar.id) {
      return failure == null ? null : pictureFailureMessage(failure);
    }
    if (server.photo == null) {
      _evictPhoto(before.photo);
      return null;
    }
    // Saved, but this server keeps an uploaded photo in front of it.
    return 'Your avatar is saved, but your uploaded photo still shows '
        'in front of it.';
  }

  /// Upload the photo at [path] as their picture.
  ///
  /// The photo shows at once from the phone, marked as uploading; the
  /// server's copy replaces it once it is in. Put back if the upload
  /// fails. Returns null when it stuck, else what to tell the person.
  Future<String?> uploadPhoto(String path) async {
    final before = state.profile;
    if (before == null) return "Your profile hasn't loaded yet. Try again.";
    _changingPicture++;
    state = state.copyWith(
      localPhoto: () => path,
      uploadingPhoto: true,
      error: state.error,
    );
    final result = await _repository.uploadPicture(path);
    if (result.isLeft && !_mayHaveStuck(result.left)) {
      _changingPicture--;
      if (mounted) _putBack(before);
      return pictureFailureMessage(result.left);
    }
    final photo = result.isRight ? result.right : null;
    if (result.isRight && photo != null) {
      // Their new photo from the server's own answer, at once; the read
      // back below only confirms it.
      final shown = state.profile ?? before;
      if (mounted) {
        state = state.copyWith(
          profile: shown.withPicture(avatar: shown.avatar, photo: photo),
          uploadingPhoto: false,
          error: state.error,
        );
      }
    }
    final fresh = await _repository.getMyProfile();
    _changingPicture--;
    if (!mounted) return null;
    final server = fresh.isRight ? fresh.right : null;
    final changed = server?.photo != null &&
        !_samePicture(server!.photo, before.photo);
    if (result.isLeft && !changed) {
      _putBack(before);
      return pictureFailureMessage(result.left);
    }
    if (server != null) _showFromServer(server);
    state = state.copyWith(uploadingPhoto: false, error: state.error);
    _evictPhoto(before.photo);
    return null;
  }

  /// A failure after which the change may still have been saved: the
  /// server answered, with an error of its own. Not one where the request
  /// never arrived, or was turned down for what it carried.
  static bool _mayHaveStuck(Failure failure) =>
      (failure is ServerFailure && failure.code != '404') ||
      failure is UnknownFailure;

  static bool _samePicture(ImageUrls? a, ImageUrls? b) {
    final x = a?.urlFor(), y = b?.urlFor();
    if (x == null || y == null) return x == y;
    return imageCacheKey(x) == imageCacheKey(y);
  }

  /// The profile as the server has it, keeping the photo from the phone
  /// under it while the uploaded copy loads.
  void _showFromServer(UserProfile server) {
    state = state.copyWith(
      profile: server,
      localPhoto: server.photo == null ? () => null : null,
      error: state.error,
    );
  }

  /// An uploaded photo that was replaced leaves the picture cache.
  void _evictPhoto(ImageUrls? old) {
    if (old != null) _evict(old.allUrls);
  }

  /// The picture [before] had, back on whatever profile is shown now.
  void _putBack(UserProfile before) {
    final shown = state.profile ?? before;
    state = state.copyWith(
      profile: shown.withPicture(avatar: before.avatar, photo: before.photo),
      localPhoto: () => null,
      uploadingPhoto: false,
      error: state.error,
    );
  }

  /// What to say when a picture change did not stick.
  static String pictureFailureMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return "You're offline, so your picture wasn't changed. Try again "
          "when you're connected.";
    }
    // The server's own words for a photo it cannot take ("That image is
    // over 5 MB. Export it smaller and try again.").
    if (failure is ValidationFailure) {
      final message = failure.message.trim();
      if (message.isNotEmpty) return message;
    }
    return "Couldn't change your picture. Try again in a moment.";
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

/// The preset avatars: the list saved on this phone at once, then the
/// server's. With nothing saved, a failure is the provider's error (the
/// picker offers to try again).
final avatarsProvider = StreamProvider.autoDispose<List<Avatar>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return savedThenFresh(
    saved: repository.getSavedAvatars,
    fresh: () async => (await repository.getAvatars()).fold(
      (failure) => throw failure,
      (avatars) => avatars,
    ),
  );
});

/// Clears pictures from the private picture cache, on disk and in memory.
typedef PictureEvictor = Future<void> Function(List<String> urls);

/// An uploaded photo that was replaced: nothing should draw it again, and
/// it should not sit in the cache for a month.
Future<void> evictPictures(List<String> urls) async {
  for (final url in urls) {
    try {
      await CachedNetworkImage.evictFromCache(
        url,
        cacheKey: imageCacheKey(url),
        cacheManager: AppImageCaches.private,
      );
    } catch (e) {
      debugPrint('evictPictures: could not clear $url: $e');
    }
  }
}

final pictureEvictorProvider =
    Provider<PictureEvictor>((ref) => evictPictures);
