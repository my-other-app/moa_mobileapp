import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/features/auth/presentation/providers/auth_provider.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/features/main/presentation/pages/landing_page.dart';

///
/// Auth Wrapper - migrated to Riverpod
///
/// This widget detects whether a user is logged in or not and shows the appropriate page
///
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Show loading while auth is initializing
    if (!authState.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if user is authenticated
    if (authState.isAuthenticated) {
      return LandingPage();
    } else {
      return OnboardingInitialPage();
    }
  }
}
