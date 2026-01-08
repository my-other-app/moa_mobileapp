import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Auth pages
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/profile_check_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_interests_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_avatar_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/success_pages.dart';
import 'package:myotherapp/features/auth/presentation/providers/auth_provider.dart';

// Main screens
import 'package:myotherapp/features/home/presentation/pages/home_page.dart';
import 'package:myotherapp/features/events/presentation/pages/events_page.dart';
import 'package:myotherapp/features/events/presentation/pages/event_detail_page.dart';
import 'package:myotherapp/features/clubs/presentation/pages/clubs_page.dart';
import 'package:myotherapp/features/clubs/presentation/pages/club_detail_page.dart';
import 'package:myotherapp/features/clubs/presentation/pages/explore_clubs_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/profile_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/settings_page.dart';
import 'package:myotherapp/features/main/presentation/pages/main_shell.dart';

// Placeholder pages
import 'package:myotherapp/features/common/presentation/pages/placeholder_pages.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider with auth-based redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isOnAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnOnboarding = state.matchedLocation.startsWith('/onboarding');

      if (!authState.isInitialized) {
        return null;
      }
      if (!isLoggedIn && !isOnAuthRoute && !isOnOnboarding) {
        return '/auth/onboarding';
      }
      if (isLoggedIn && state.matchedLocation == '/auth/onboarding') {
        return '/auth/profile-check';
      }
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
          path: '/auth/onboarding',
          name: 'onboarding',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const OnboardingInitialPage()),
      GoRoute(
          path: '/auth/profile-check',
          name: 'profileCheck',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ProfileCheckPage(
              accessToken: extra?['accessToken'] ?? '',
              profileUrl: extra?['profileUrl'] ?? '',
            );
          }),

      // Onboarding flow
      GoRoute(
          path: '/onboarding/details',
          name: 'onboardingDetails',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return OnboardingDetailsPage(
              initialName: extra?['initialName'],
              profileUrl: extra?['profileUrl'] ?? '',
            );
          }),
      GoRoute(
          path: '/onboarding/interests',
          name: 'onboardingInterests',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return OnboardingInterestsPage(
                isOnboarding: extra?['isOnboarding'] ?? true);
          }),
      GoRoute(
          path: '/onboarding/avatar',
          name: 'onboardingAvatar',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return OnboardingAvatarPage(
                isOnboarding: extra?['isOnboarding'] ?? true);
          }),
      GoRoute(
          path: '/onboarding/final',
          name: 'onboardingFinal',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const OnboardingFinalPage()),
      GoRoute(
          path: '/onboarding/success',
          name: 'registrationSuccess',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const RegistrationSuccessPage()),

      // Main shell with bottom nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage()),
          GoRoute(
              path: '/events',
              name: 'events',
              builder: (context, state) => const EventsPage(),
              routes: [
                GoRoute(
                    path: ':eventId',
                    name: 'eventDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => EventDetailPage(
                        eventId: int.tryParse(
                                state.pathParameters['eventId'] ?? '') ??
                            0)),
              ]),
          GoRoute(
              path: '/clubs',
              name: 'clubs',
              builder: (context, state) => const ClubsPage(),
              routes: [
                GoRoute(
                    path: 'explore',
                    name: 'exploreClubs',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ExploreClubsPage()),
                GoRoute(
                    path: ':clubId',
                    name: 'clubDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ClubDetailPage(
                        clubId: int.tryParse(
                                state.pathParameters['clubId'] ?? '') ??
                            0)),
              ]),
          GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
              routes: [
                GoRoute(
                    path: 'edit',
                    name: 'editProfile',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EditProfilePage()),
                GoRoute(
                    path: 'settings',
                    name: 'settings',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const SettingsPage(),
                    routes: [
                      GoRoute(
                          path: 'terms',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) => const TermsPage()),
                      GoRoute(
                          path: 'privacy',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) => const PrivacyPage()),
                    ]),
                GoRoute(
                    path: 'certificates',
                    name: 'certificates',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CertificatesPage()),
                GoRoute(
                    path: 'badges',
                    name: 'badges',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const BadgesPage()),
                GoRoute(
                    path: 'notifications',
                    name: 'notifications',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const NotificationsPage()),
              ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Page not found',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        ElevatedButton(
            onPressed: () => context.go('/'), child: const Text('Go Home')),
      ])),
    ),
  );
});

class AppRoutes {
  AppRoutes._();
  static const String onboarding = 'onboarding';
  static const String profileCheck = 'profileCheck';
  static const String onboardingDetails = 'onboardingDetails';
  static const String onboardingAvatar = 'onboardingAvatar';
  static const String onboardingInterests = 'onboardingInterests';
  static const String onboardingFinal = 'onboardingFinal';
  static const String registrationSuccess = 'registrationSuccess';
  static const String home = 'home';
  static const String events = 'events';
  static const String eventDetail = 'eventDetail';
  static const String clubs = 'clubs';
  static const String exploreClubs = 'exploreClubs';
  static const String clubDetail = 'clubDetail';
  static const String profile = 'profile';
  static const String editProfile = 'editProfile';
  static const String settings = 'settings';
  static const String certificates = 'certificates';
  static const String badges = 'badges';
  static const String notifications = 'notifications';
}
