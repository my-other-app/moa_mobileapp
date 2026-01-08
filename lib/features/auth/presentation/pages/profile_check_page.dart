import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/features/auth/presentation/providers/auth_provider.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart'
    hide ProfileState;
import 'package:myotherapp/features/main/presentation/pages/landing_page.dart';
import 'package:myotherapp/features/auth/presentation/cubits/profile_cubit.dart';
import 'package:myotherapp/features/auth/data/models/profile.dart';
import 'package:myotherapp/features/auth/data/services/profile_service.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';

/// Profile Check Page - fully migrated to Riverpod and callback-based ProfileCubit.
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
        final tokenModel = await SecureStorage.instance.getAccessToken();

        if (mounted) {
          // Update Riverpod auth state
          await ref.read(authStateProvider.notifier).setAuthenticated(
                accessToken: widget.accessToken,
                refreshToken: tokenModel.refreshToken,
              );

          // Load profile into Riverpod provider
          await ref.read(profileProvider.notifier).loadProfile();

          // Check the interest field from the nested profile.
          final ProfileDetails? profile = state.profile.profile;
          if (!mounted) return;

          if (profile == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OnboardingDetailsPage(
                  profileUrl: widget.profileUrl,
                  initialName: state.profile.fullName,
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LandingPage()),
            );
          }
        }
      } catch (error) {
        debugPrint("Error getting tokens: $error");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingInitialPage(),
            ),
          );
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
