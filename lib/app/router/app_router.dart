import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Analytics
import 'package:myotherapp/core/services/analytics_service.dart';

// Auth pages
import 'package:myotherapp/features/auth/presentation/pages/splash_screen.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/profile_check_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/interests_selection_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_avatar_picker_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_final_page.dart';
import 'package:myotherapp/features/auth/presentation/pages/reg_successfull_page.dart';
import 'package:myotherapp/features/auth/presentation/providers/auth_provider.dart';

// Main screens
import 'package:myotherapp/features/home/presentation/pages/home_page.dart';
import 'package:myotherapp/features/events/presentation/pages/events_page.dart';
import 'package:myotherapp/features/events/presentation/pages/individual_event_page.dart';
import 'package:myotherapp/features/events/presentation/pages/event_form_page.dart';
import 'package:myotherapp/features/clubs/presentation/pages/clubs_page.dart';
import 'package:myotherapp/features/clubs/presentation/pages/club_individual_page.dart';
import 'package:myotherapp/features/clubs/presentation/pages/explore_more_clubs_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/profile_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/settings_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/certificates/certificate_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/badges/my_badges_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/notifications/notifications_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/settings/terms_and_condition_page.dart';
import 'package:myotherapp/features/profile/presentation/pages/settings/privacy_policy_page.dart';
import 'package:myotherapp/features/main/presentation/pages/main_shell.dart';
import 'package:myotherapp/common/models/events/event_model.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider with auth-based redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    // Add analytics observer for automatic screen tracking
    observers: [AnalyticsService.instance.observer],
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isOnAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnOnboarding = state.matchedLocation.startsWith('/onboarding');
      final isOnSplash = state.matchedLocation == '/splash';

      // Let splash screen handle its own navigation
      if (isOnSplash) {
        return null;
      }

      if (!authState.isInitialized) {
        return '/splash';
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
      // Splash screen route
      GoRoute(
          path: '/splash',
          name: 'splash',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const SplashScreen()),
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
            return InterestsSelectionPage(
                isOnboarding: extra?['isOnboarding'] ?? true);
          }),
      GoRoute(
          path: '/onboarding/avatar',
          name: 'onboardingAvatar',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const OnboardingAvatarPickerPage()),
      GoRoute(
          path: '/onboarding/complete',
          name: 'onboardingComplete',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const OnboardingFinalPage()),

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
                    path: 'registration-success',
                    name: 'eventRegistrationSuccess',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return RegSuccessfullPage(
                        ticketId: extra?['ticketId'],
                        eventName: extra?['eventName'],
                        eventId: extra?['eventId'],
                        eventDateTime: extra?['eventDateTime'],
                        fullName: extra?['fullName'],
                      );
                    }),
                GoRoute(
                    path: ':eventId',
                    name: 'eventDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return IndividualEventPage(
                        eventId: int.tryParse(
                                state.pathParameters['eventId'] ?? '') ??
                            0,
                        initialStatus: extra?['status'],
                        initialTicketUrl: extra?['ticketUrl'],
                        initialCertificateUrl: extra?['certificateUrl'],
                      );
                    },
                    routes: [
                      GoRoute(
                          path: 'register',
                          name: 'eventRegister',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) {
                            final extra = state.extra as Map<String, dynamic>?;
                            final additionalDetails =
                                extra?['additionalDetails']
                                        as List<AdditionalDetail>? ??
                                    [];
                            return EventFormPage(
                              eventId: int.tryParse(
                                      state.pathParameters['eventId'] ?? '') ??
                                  0,
                              additionalDetails: additionalDetails,
                            );
                          }),
                    ]),
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
                    builder: (context, state) => ExploreMoreClubsPage()),
                GoRoute(
                    path: ':clubId',
                    name: 'clubDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return ClubIndividualPage(
                        clubId: int.tryParse(
                                state.pathParameters['clubId'] ?? '') ??
                            0,
                        clubSlug: extra?['clubSlug'] ?? '',
                        clubname: extra?['clubName'] ?? '',
                      );
                    }),
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
                    path: 'interests',
                    name: 'profileInterests',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const InterestsSelectionPage(isOnboarding: false)),
                GoRoute(
                    path: 'settings',
                    name: 'settings',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const SettingsPage(),
                    routes: [
                      GoRoute(
                          path: 'terms',
                          name: 'terms',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) => TermsAndConditionPage()),
                      GoRoute(
                          path: 'privacy',
                          name: 'privacy',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) => PrivacyPolicyPage()),
                    ]),
                GoRoute(
                    path: 'certificates',
                    name: 'certificates',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => CertificatePage()),
                GoRoute(
                    path: 'badges',
                    name: 'badges',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MyBadgesPage()),
                GoRoute(
                    path: 'notifications',
                    name: 'notifications',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => NotificationsNewPage()),
              ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Page not found: ${state.matchedLocation}',
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
  static const String onboardingComplete = 'onboardingComplete';
  static const String home = 'home';
  static const String events = 'events';
  static const String eventDetail = 'eventDetail';
  static const String eventRegister = 'eventRegister';
  static const String eventRegistrationSuccess = 'eventRegistrationSuccess';
  static const String clubs = 'clubs';
  static const String exploreClubs = 'exploreClubs';
  static const String clubDetail = 'clubDetail';
  static const String profile = 'profile';
  static const String editProfile = 'editProfile';
  static const String profileInterests = 'profileInterests';
  static const String settings = 'settings';
  static const String terms = 'terms';
  static const String privacy = 'privacy';
  static const String certificates = 'certificates';
  static const String badges = 'badges';
  static const String notifications = 'notifications';
}
