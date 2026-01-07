import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/features/auth/presentation/providers/auth_provider.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';

/// Profile check page that determines where to navigate after login.
///
/// Checks if the user's profile is complete and navigates accordingly:
/// - If profile incomplete → Onboarding details
/// - If profile complete → Home
class ProfileCheckPage extends ConsumerStatefulWidget {
  const ProfileCheckPage({super.key});

  @override
  ConsumerState<ProfileCheckPage> createState() => _ProfileCheckPageState();
}

class _ProfileCheckPageState extends ConsumerState<ProfileCheckPage> {
  bool _hasCheckedProfile = false;

  @override
  void initState() {
    super.initState();
    // Load profile on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfile();
    });
  }

  Future<void> _checkProfile() async {
    if (_hasCheckedProfile) return;
    _hasCheckedProfile = true;

    // Load the user's profile
    await ref.read(profileProvider.notifier).loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to profile state changes
    ref.listen<ProfileState>(profileProvider, (previous, current) {
      if (current.error != null) {
        // Profile fetch failed - might need to create profile
        debugPrint('Profile error: ${current.error}');
        context.goNamed('onboardingDetails');
        return;
      }

      if (!current.isLoading && current.profile != null) {
        final profile = current.profile!;

        if (profile.isProfileComplete) {
          // Profile is complete - go to home
          debugPrint('Profile complete, navigating to home');
          context.goNamed('home');
        } else {
          // Profile incomplete - go to onboarding
          debugPrint('Profile incomplete, navigating to details');
          context.goNamed('onboardingDetails');
        }
      }
    });

    // Also listen for auth state to handle logout
    ref.listen<AuthState>(authStateProvider, (previous, current) {
      if (!current.isAuthenticated && current.isInitialized) {
        // User logged out - go to login
        context.goNamed('onboarding');
      }
    });

    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF17A58F)),
            ),
            const SizedBox(height: 24),
            Text(
              profileState.isLoading
                  ? 'Loading your profile...'
                  : 'Setting things up...',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1a1a2e),
              ),
            ),
            if (profileState.error != null) ...[
              const SizedBox(height: 16),
              Text(
                profileState.error!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
