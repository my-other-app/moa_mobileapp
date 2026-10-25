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
import 'package:finnet/features/events/presentation/pages/explore_events_page.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/events_routes.dart';
import 'package:finnet/features/live/live_routes.dart';
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
import 'package:finnet/features/discover/presentation/discover_routes.dart';

// Batch C's routes (auth, threads, profile)
import 'package:finnet/features/auth/presentation/auth_routes.dart';
import 'package:finnet/features/threads/presentation/threads_routes.dart';
import 'package:finnet/features/profile/presentation/profile_routes.dart';

// Volunteer pages
import 'package:finnet/features/volunteer/presentation/pages/volunteer_events_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_scanner_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/manual_ticket_entry_page.dart';

// Signed-out browsing and the website's links
import 'package:finnet/app/router/link_pages.dart';
import 'package:finnet/app/router/pending_location.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';

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

/// Where the router sends someone at [location] (a path and query), or
/// null to let them in.
///
/// The app is open without an account (route_access.dart): signed out,
/// only an address that is about the person -- their events and tickets,
/// clubs, profile, settings, the scanner, registering -- leads to sign-in,
/// which comes back to it afterwards (`?from=`). That is also how an ended
/// session on such a page reaches sign-in: the auth state changes and the
/// router re-runs this on the page the person is on.
///
/// [launchLink] is a link that opened the app and waits for the splash
/// screen to finish. The splash sends a signed-out person to sign-in; with
/// a link waiting, a public one opens over home instead, and a private one
/// asks for sign-in first and then opens.
@visibleForTesting
String? authRedirect(AuthState auth, String location, {String? launchLink}) {
  final uri = Uri.parse(location);
  final path = uri.path.isEmpty ? '/' : uri.path;
  // The splash screen routes itself once the stored session has been read.
  if (path == '/splash') return null;
  if (!auth.isInitialized) return '/splash';

  if (auth.isAuthenticated) {
    // Signed in on the sign-in screen: on to the profile check, which
    // takes an existing account straight back to `from`.
    return path == signInPath ? profileCheckLocation(returnTarget(uri)) : null;
  }
  if (isAuthFlow(path)) {
    if (path == signInPath && launchLink != null && returnTarget(uri) == null) {
      return needsAccount(launchLink) ? signInLocation(launchLink) : '/';
    }
    return null;
  }
  return needsAccount(path) ? signInLocation(location) : null;
}

/// Whether [location] is a link worth holding while the app starts: an
/// address of a page, not the start or the sign-in flow.
bool _isLaunchLink(String location) {
  final path = Uri.parse(location).path;
  return path.isNotEmpty && path != '/' && !isAuthFlow(path);
}

/// Feature routes (absolute paths, as each feature writes them) re-rooted
/// under Home, on the root navigator: a page a link opens from outside the
/// app then has Home under it, so Back -- or the app bar's back button on
/// an iPhone -- leads into the app rather than out of it.
///
/// Only [GoRoute]s: a feature's own shell route goes in the top-level list.
@visibleForTesting
List<RouteBase> overHome(
  GlobalKey<NavigatorState> rootKey,
  List<RouteBase> routes,
) {
  GoRoute onRoot(RouteBase route) {
    if (route is! GoRoute) {
      throw ArgumentError.value(route, 'routes',
          'overHome takes GoRoutes; put a ShellRoute in the top-level list');
    }
    return GoRoute(
      path: route.path.startsWith('/') ? route.path.substring(1) : route.path,
      name: route.name,
      builder: route.builder,
      pageBuilder: route.pageBuilder,
      redirect: route.redirect,
      onExit: route.onExit,
      parentNavigatorKey: rootKey,
      // A sub-page (a topic under the topics) on the root navigator too:
      // left alone, it would open inside the tabs, under its own parent.
      routes: [for (final child in route.routes) onRoot(child)],
    );
  }

  return [for (final route in routes) onRoot(route)];
}

/// `/clubs/{clubId}`: the club, by id or by the website's slug. The
/// parameter keeps its old name; it is a string ref. A slug alone is
/// enough: the page reads the club's public page to find it.
Widget _buildClubPage(BuildContext context, GoRouterState state) {
  final extra = state.extra as Map<String, dynamic>?;
  final ref = state.pathParameters['clubId'] ?? '';
  final id = int.tryParse(ref);
  return ClubIndividualPage(
    clubId: id ?? 0,
    clubSlug: extra?['clubSlug'] as String? ?? (id == null ? ref : ''),
    clubname: extra?['clubName'] as String? ?? '',
  );
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
  final pending = ref.read(pendingLocationProvider);

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
    redirect: (context, state) {
      // A universal link or an App Link arrives as the whole URL: the
      // website's address, read as the app's (web_links.dart).
      final fromWebsite = appLocationForLink(state.uri);
      if (fromWebsite != null) return fromWebsite;
      final location = state.uri.toString();
      final now = auth.value;
      // A link that opened the app arrives while the splash screen reads
      // the stored session: held, and opened once the splash is done.
      if (!now.isInitialized && _isLaunchLink(location)) {
        pending.holdLaunch(location);
      }
      return authRedirect(now, location,
          launchLink: pending.fromLaunch ? pending.location : null);
    },
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
          builder: (context, state) => SignInPageFrame(
                location: state.uri,
                child: const OnboardingInitialPage(),
              )),
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

      // Forgot password: a sign-in step, so no Home under it.
      ...authRoutes,
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

      // Main shell with bottom nav
      // The tabs first: Home's pages come last, so `/events/explore` is not
      // taken for an event called "explore".
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // My events: registrations and tickets. Signed in only.
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
              ]),
          // My clubs: followed and pinned. Signed in only.
          GoRoute(
              path: '/clubs',
              name: 'clubs',
              builder: (context, state) => const ClubsPage()),
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
                            final extra = state.extra as Map<String, dynamic>?;
                            final certificate =
                                extra?['certificate'] as Certificate?;
                            // Reached from the list, which passes the
                            // certificate it already has. Without one, the
                            // certificate's link page finds it (or shows the
                            // public page).
                            if (certificate == null) {
                              return CertificateLinkPage(
                                  ticketId:
                                      state.pathParameters['ticketId'] ?? '');
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
          // Home, and every page that is open without an account, above it
          // on the root navigator. A link from outside the app opens one of
          // these with Home underneath. Their paths are the website's
          // (web_links.dart), so the site's links open them as they are.
          GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage(),
              routes: [
                // The features' public pages: Find events, the clubs
                // directory, every club's posts and the topics (batch A);
                // the competition and the feedback survey (B); posts from
                // followed clubs and checking a certificate (C). Before the
                // event's page, so `/events/{ref}/compete` is the
                // competition.
                ...overHome(rootKey, discoverRoutes),
                ...overHome(rootKey, eventsRoutes),
                ...overHome(rootKey, threadsRoutes),
                ...overHome(rootKey, profileRoutes),
                GoRoute(
                    path: 'events/explore',
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
                    path: 'clubs/explore',
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
                // An event, by id or by the website's slug.
                GoRoute(
                    path: 'events/:eventId',
                    name: 'eventDetail',
                    parentNavigatorKey: rootKey,
                    builder: buildEventPage,
                    // `?live=` (older pushes and links): the room itself.
                    redirect: legacyLiveRedirect,
                    routes: [
                      GoRoute(
                          path: 'register',
                          name: 'eventRegister',
                          parentNavigatorKey: rootKey,
                          builder: buildEventRegisterPage),
                      // The live room, in the app (the website's address
                      // too), and its quiz.
                      GoRoute(
                          path: 'live',
                          name: 'eventLive',
                          parentNavigatorKey: rootKey,
                          builder: buildLiveRoomPage,
                          routes: [
                            GoRoute(
                                path: 'quiz',
                                name: 'eventLiveQuiz',
                                parentNavigatorKey: rootKey,
                                builder: buildQuizPage),
                          ]),
                    ]),
                // A club, by id or by the website's slug.
                GoRoute(
                  path: 'clubs/:clubId',
                  name: 'clubDetail',
                  parentNavigatorKey: rootKey,
                  builder: _buildClubPage,
                ),
                // A club's post, with its comments. Not under its club: a
                // tapped notification knows the post and not the club.
                GoRoute(
                    path: 'threads/:threadId',
                    name: 'threadDetail',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => ThreadDetailPage(
                          threadId: state.pathParameters['threadId'] ?? '',
                        )),
                // A ticket, from what the phone has saved: opens with no
                // network, and from its link with no account (its QR is
                // the ticket, as on the website's page).
                GoRoute(
                    path: 'tickets/:code',
                    name: 'ticket',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => SavedTicketPage(
                          code: state.pathParameters['code'] ?? '',
                          revoked: (state.extra
                                  as Map<String, dynamic>?)?['revoked'] ==
                              true,
                        )),
                // A certificate from its link: the person's own in the app,
                // anyone else's on its public page.
                GoRoute(
                    path: 'certificates/:ticketId',
                    name: 'certificateLink',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => CertificateLinkPage(
                          ticketId: state.pathParameters['ticketId'] ?? '',
                        )),
              ]),
        ],
      ),
    ],
    // An address the app has no screen for: never "Page not found: path".
    errorBuilder: (context, state) =>
        LinkNotFoundPage(location: state.uri.toString()),
  );

  // What was waiting -- the link that opened the app, or where a sign-in
  // returns to -- opens once the router lands on Home.
  final openPending = openPendingOnHome(router, auth, pending);

  ref.onDispose(() {
    router.routerDelegate.removeListener(openPending);
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
  static const String eventLive = 'eventLive';
  static const String eventLiveQuiz = 'eventLiveQuiz';
  static const String eventRegistrationSuccess = 'eventRegistrationSuccess';
  static const String clubs = 'clubs';
  static const String exploreClubs = 'exploreClubs';
  static const String exploreEvents = 'exploreEvents';
  static const String clubDetail = 'clubDetail';
  static const String threadDetail = 'threadDetail';
  static const String ticket = 'ticket';
  static const String certificateLink = 'certificateLink';
  static const String profile = 'profile';
  static const String editProfile = 'editProfile';
  static const String profileInterests = 'profileInterests';
  static const String settings = 'settings';
  static const String certificates = 'certificates';
  static const String badges = 'badges';
  static const String notifications = 'notifications';
}
