import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart'
    hide ProfileState;
import 'package:finnet/features/auth/presentation/cubits/profile_cubit.dart';
import 'package:finnet/features/auth/data/models/profile.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';

/// Profile Check Page - fully migrated to Riverpod and GoRouter.
class ProfileCheckPage extends ConsumerStatefulWidget {
  final String accessToken;
  final String profileUrl;

  const ProfileCheckPage({
    super.key,
    required this.accessToken,
    required this.profileUrl,
  });

  @override
  ConsumerState<ProfileCheckPage> createState() => _ProfileCheckPageState();
}

class _ProfileCheckPageState extends ConsumerState<ProfileCheckPage> {
  late ProfileCubit _profileCubit;

  /// Why the profile could not be loaded, while it could not.
  ProfileFailure? _failure;

  @override
  void initState() {
    super.initState();
    _profileCubit = ProfileCubit(profileService: ProfileService());
    _profileCubit.onStateChanged = _handleProfileStateChange;

    // Fetch profile after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted && _failure != null) setState(() => _failure = null);
    await _profileCubit.getProfile(await _accessToken());
  }

  /// The session's access token. The one sign-in stored is the freshest:
  /// the profile request may have refreshed it, and the redirect for a
  /// signed-in person opening /auth/onboarding brings them here with none.
  Future<String> _accessToken() async {
    try {
      final stored =
          await ref.read(secureStorageServiceProvider).getAccessToken();
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (e) {
      debugPrint('ProfileCheck: could not read the stored token: $e');
    }
    return widget.accessToken;
  }

  void _handleProfileStateChange(ProfileState state) async {
    if (!mounted) return;

    if (state is ProfileLoaded) {
      debugPrint("Full profile data: ${state.profile}");

      try {
        final secureStorage = ref.read(secureStorageServiceProvider);
        final accessToken = await _accessToken();
        final refreshToken = await secureStorage.getRefreshToken();

        if (mounted) {
          // Update Riverpod auth state
          await ref.read(authStateProvider.notifier).setAuthenticated(
                accessToken: accessToken,
                refreshToken: refreshToken ?? '',
              );

          // Load profile into Riverpod provider
          await ref.read(profileProvider.notifier).loadProfile();

          // Check the interest field from the nested profile.
          final ProfileDetails? profile = state.profile.profile;
          if (!mounted) return;

          if (profile == null) {
            context.go('/onboarding/details', extra: {
              'profileUrl': widget.profileUrl,
              'initialName': state.profile.fullName,
            });
          } else {
            context.go('/');
          }
        }
      } catch (error) {
        debugPrint("Error getting tokens: $error");
        if (mounted) {
          context.go('/auth/onboarding');
        }
      }
    } else if (state is ProfileFailure) {
      // Said on the page, with a way on. It used to be a "Profile error: ..."
      // snackbar over a spinner that never stopped.
      if (mounted) setState(() => _failure = state);
    }
  }

  /// Leave a session that cannot go on, and start again at sign-in.
  Future<void> _backToSignIn() async {
    try {
      await ref.read(secureStorageServiceProvider).clearTokens();
    } catch (e) {
      debugPrint('ProfileCheck: could not clear tokens: $e');
    }
    if (mounted) context.go('/auth/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  failure.error,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (!failure.needsSignIn)
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                TextButton(
                  onPressed: _backToSignIn,
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
