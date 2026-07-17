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

  @override
  void initState() {
    super.initState();
    _profileCubit = ProfileCubit(profileService: ProfileService());
    _profileCubit.onStateChanged = _handleProfileStateChange;

    // Fetch profile after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileCubit.getProfile(widget.accessToken);
    });
  }

  void _handleProfileStateChange(ProfileState state) async {
    if (!mounted) return;

    if (state is ProfileLoaded) {
      debugPrint("Full profile data: ${state.profile}");

      try {
        final secureStorage = ref.read(secureStorageServiceProvider);
        final refreshToken = await secureStorage.getRefreshToken();

        if (mounted) {
          // Update Riverpod auth state
          await ref.read(authStateProvider.notifier).setAuthenticated(
                accessToken: widget.accessToken,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile error: ${state.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
