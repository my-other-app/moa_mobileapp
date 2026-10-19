import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Analytics
import 'package:finnet/core/services/analytics_service.dart';

// Auth pages
import 'package:finnet/features/auth/presentation/pages/splash_screen.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:finnet/features/auth/presentation/pages/profile_check_page.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:finnet/features/auth/presentation/pages/interests_selection_page.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_avatar_picker_page.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_final_page.dart';
import 'package:finnet/features/auth/presentation/pages/reg_successfull_page.dart';
import 'package:finnet/features/auth/presentation/pages/verify_email_page.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

// Main screens
import 'package:finnet/features/home/presentation/pages/home_page.dart';
import 'package:finnet/features/events/presentation/pages/events_page.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/pages/explore_events_page.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/clubs/presentation/pages/clubs_page.dart';
import 'package:finnet/features/clubs/presentation/pages/club_individual_page.dart';
import 'package:finnet/features/clubs/presentation/pages/explore_more_clubs_page.dart';
import 'package:finnet/features/threads/presentation/pages/thread_detail_page.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';
import 'package:finnet/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:finnet/features/profile/presentation/pages/settings_page.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_detail_page.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_page.dart';
import 'package:finnet/features/profile/presentation/pages/badges/my_badges_page.dart';
import 'package:finnet/features/profile/presentation/pages/notifications/notifications_page.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:finnet/common/models/events/event_model.dart';

// Batch C's routes (auth, threads, profile)
import 'package:finnet/features/auth/presentation/auth_routes.dart';
import 'package:finnet/features/threads/presentation/threads_routes.dart';
import 'package:finnet/features/profile/presentation/profile_routes.dart';

// Volunteer pages
import 'package:finnet/features/volunteer/presentation/pages/volunteer_events_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_scanner_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/manual_ticket_entry_page.dart';

GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// The current router's root navigator, so a tapped notification can open a
/// page from outside the tree. Each session's router has its own.
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

/// Navigator observers for the router: analytics screen tracking. A provider
/// so tests can leave it out -- the analytics observer needs Firebase.
final routerObserversProvider = Provider<List<NavigatorObserver>>(
  (ref) => [AnalyticsService.instance.observer],
);

/// Where the router sends someone at [location], or null to let them in.
///
/// Signed out, everything but the sign-in and onboarding screens leads to
/// sign-in -- which is how an ended session reaches the screen: the auth
/// state changes, the router re-runs this, and the person lands on sign-in.
@visibleForTesting
String? authRedirect(AuthState auth, String location) {
  // The splash screen routes itself once the stored session has been read.
  if (location == '/splash') return null;
  if (!auth.isInitialized) return '/splash';

  final isOnAuthRoute = location.startsWith('/auth');
  final isOnOnboarding = location.startsWith('/onboarding');
  if (!auth.isAuthenticated && !isOnAuthRoute && !isOnOnboarding) {
    return '/auth/onboarding';
  }
  if (auth.isAuthenticated && location == '/auth/onboarding') {
    return '/auth/profile-check';
  }
  return null;
}

/// GoRouter provider with auth-based redirects.
///
/// Built once per session (see `SessionScope`) and told about auth changes
/// through `refreshListenable`. It used to `watch` the auth state, which
/// built a whole new router -- back at the splash screen -- on every change:
/// signing in threw away the profile check's own navigation, so a new
/// account went straight home and never reached the onboarding details.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authStateProvider));
  ref.listen<AuthState>(authStateProvider, (_, next) => auth.value = next);

  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
  _rootNavigatorKey = rootKey;

  final start = auth.value;
  final router = GoRouter(
    navigatorKey: rootKey,
    // A session scope that starts after a sign-out already knows nobody is
    // signed in: straight to sign-in, without the splash screen again.
    initialLocation: start.isInitialized && !start.isAuthenticated
        ? '/auth/onboarding'
        : '/splash',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: auth,
    // Add analytics observer for automatic screen tracking
    observers: ref.read(routerObserversProvider),
    redirect: (context, state) =>
        authRedirect(auth.value, state.matchedLocation),
    routes: [
      // Splash screen route
      GoRoute(
          path: '/splash',
          name: 'splash',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const SplashScreen()),
      // Auth routes
      GoRoute(
          path: '/auth/onboarding',
          name: 'onboarding',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const OnboardingInitialPage()),
      GoRoute(
          path: '/auth/profile-check',
          name: 'profileCheck',
          parentNavigatorKey: rootKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ProfileCheckPage(
              accessToken: extra?['accessToken'] ?? '',
              profileUrl: extra?['profileUrl'] ?? '',
            );
          }),
      // The code sent to an email/password account's address. Under /auth so
      // it opens straight after sign-up, before the session is in auth state;
      // the banner and Settings push it for a signed-in account too.
      GoRoute(
          path: '/auth/verify-email',
          name: 'verifyEmail',
          parentNavigatorKey: rootKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return VerifyEmailPage(
              email: extra?['email'] as String? ?? '',
              onboarding: extra?['onboarding'] == true,
              accessToken: extra?['accessToken'] as String? ?? '',
              profileUrl: extra?['profileUrl'] as String? ?? '',
            );
          }),

      ...authRoutes, ...threadsRoutes, ...profileRoutes,
      // Onboarding flow
      GoRoute(
          path: '/onboarding/details',
          name: 'onboardingDetails',
          parentNavigatorKey: rootKey,
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
          parentNavigatorKey: rootKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return InterestsSelectionPage(
                isOnboarding: extra?['isOnboarding'] ?? true);
          }),
      GoRoute(
          path: '/onboarding/avatar',
          name: 'onboardingAvatar',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const OnboardingAvatarPickerPage()),
      GoRoute(
          path: '/onboarding/complete',
          name: 'onboardingComplete',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const OnboardingFinalPage()),

      // Volunteer routes
      GoRoute(
          path: '/volunteer/events',
          name: 'volunteerEvents',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const VolunteerEventsPage()),
      GoRoute(
          path: '/volunteer/scanner/:eventId',
          name: 'volunteerScanner',
          parentNavigatorKey: rootKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return VolunteerScannerPage(
              eventId: int.tryParse(state.pathParameters['eventId'] ?? '') ?? 0,
              eventName: extra['eventName'] as String? ?? 'Event',
              clubName: extra['clubName'] as String? ?? '',
            );
          }),
      GoRoute(
          path: '/volunteer/manual-entry/:eventId',
          name: 'volunteerManualEntry',
          parentNavigatorKey: rootKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return ManualTicketEntryPage(
              eventId: int.tryParse(state.pathParameters['eventId'] ?? '') ?? 0,
              eventName: extra['eventName'] as String? ?? 'Event',
              clubName: extra['clubName'] as String? ?? '',
            );
          }),

      // A club's post, with its comments. Top level rather than under
      // /clubs/:clubId, because a tapped notification knows the post and
      // not the club.
      GoRoute(
          path: '/threads/:threadId',
          name: 'threadDetail',
          parentNavigatorKey: rootKey,
          builder: (context, state) => ThreadDetailPage(
                threadId: state.pathParameters['threadId'] ?? '',
              )),

      // A ticket, from what the phone has saved: opens with no network.
      GoRoute(
          path: '/tickets/:code',
          name: 'ticket',
          parentNavigatorKey: rootKey,
          builder: (context, state) => SavedTicketPage(
                code: state.pathParameters['code'] ?? '',
                revoked: (state.extra as Map<String, dynamic>?)?['revoked'] ==
                    true,
              )),

      // Main shell with bottom nav
      ShellRoute(
        navigatorKey: shellKey,
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
                    parentNavigatorKey: rootKey,
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
                // Before ':eventId', which would take "explore" for an id.
                GoRoute(
                    path: 'explore',
                    name: 'exploreEvents',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return ExploreEventsPage(
                        initialTopic: extra?['topic'] as String? ??
                            state.uri.queryParameters['topic'],
                        initialInterestId: extra?['interestId'] as int? ??
                            int.tryParse(
                                state.uri.queryParameters['interest'] ?? ''),
                      );
                    }),
                GoRoute(
                    path: ':eventId',
                    name: 'eventDetail',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return IndividualEventPage(
                        eventId: int.tryParse(
                                state.pathParameters['eventId'] ?? '') ??
                            0,
                        initialStatus: extra?['status'],
                        initialTicketUrl: extra?['ticketUrl'],
                        initialCertificateUrl: extra?['certificateUrl'],
                        // ?live=quiz|poll|room: a "join now" push.
                        openLiveRoom:
                            state.uri.queryParameters.containsKey('live'),
                      );
                    },
                    routes: [
                      GoRoute(
                          path: 'register',
                          name: 'eventRegister',
                          parentNavigatorKey: rootKey,
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
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final legacyIds = extra?['interestIds'] is List
                          ? List<int>.from(extra!['interestIds'] as List)
                          : const <int>[];
                      return ExploreMoreClubsPage(
                        initialOrganizationId: extra?['organizationId'] as int?,
                        initialTopic: extra?['topic'] as String? ??
                            state.uri.queryParameters['topic'],
                        initialInterestId: extra?['interestId'] as int? ??
                            int.tryParse(
                                state.uri.queryParameters['interest'] ?? '') ??
                            legacyIds.firstOrNull,
                      );
                    }),
                GoRoute(
                    path: ':clubId',
                    name: 'clubDetail',
                    parentNavigatorKey: rootKey,
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
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const EditProfilePage()),
                GoRoute(
                    path: 'interests',
                    name: 'profileInterests',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) =>
                        const InterestsSelectionPage(isOnboarding: false)),
                // Privacy Policy and Terms open myotherapp.in/privacy and
                // /terms in the browser (shared/utils/external_links.dart);
                // there are no in-app copies to keep in step.
                GoRoute(
                    path: 'settings',
                    name: 'settings',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const SettingsPage()),
                GoRoute(
                    path: 'certificates',
                    name: 'certificates',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => CertificatePage(),
                    routes: [
                      GoRoute(
                          path: ':ticketId',
                          name: 'certificateDetail',
                          parentNavigatorKey: rootKey,
                          builder: (context, state) {
                            final extra =
                                state.extra as Map<String, dynamic>?;
                            final certificate =
                                extra?['certificate'] as Certificate?;
                            // Reached only from the list, which passes the
                            // certificate it already has. A deep link has
                            // nothing to show, so it goes back to the list
                            // rather than rendering an empty screen.
                            if (certificate == null) {
                              return const CertificatePage();
                            }
                            return CertificateDetailPage(
                                certificate: certificate);
                          }),
                    ]),
                GoRoute(
                    path: 'badges',
                    name: 'badges',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const MyBadgesPage()),
                GoRoute(
                    path: 'notifications',
                    name: 'notifications',
                    parentNavigatorKey: rootKey,
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
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});

class AppRoutes {
  AppRoutes._();
  static const String onboarding = 'onboarding';
  static const String profileCheck = 'profileCheck';
  static const String verifyEmail = 'verifyEmail';
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
  static const String exploreEvents = 'exploreEvents';
  static const String clubDetail = 'clubDetail';
  static const String threadDetail = 'threadDetail';
  static const String profile = 'profile';
  static const String editProfile = 'editProfile';
  static const String profileInterests = 'profileInterests';
  static const String settings = 'settings';
  static const String certificates = 'certificates';
  static const String badges = 'badges';
  static const String notifications = 'notifications';
}
