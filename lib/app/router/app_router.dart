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

// Volunteer pages
import 'package:finnet/features/volunteer/presentation/pages/volunteer_events_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_scanner_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/manual_ticket_entry_page.dart';

// Signed-out browsing and the website's links
import 'package:finnet/app/router/link_pages.dart';
import 'package:finnet/app/router/pending_location.dart';
import 'package:finnet/app/router/route_access.dart';

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
    return path == signInPath ? '/auth/profile-check' : null;
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
  return [
    for (final route in routes)
      if (route is GoRoute)
        GoRoute(
          path: route.path.startsWith('/')
              ? route.path.substring(1)
              : route.path,
          name: route.name,
          builder: route.builder,
          pageBuilder: route.pageBuilder,
          redirect: route.redirect,
          onExit: route.onExit,
          parentNavigatorKey: rootKey,
          routes: route.routes,
        )
      else
        throw ArgumentError.value(route, 'routes',
            'overHome takes GoRoutes; put a ShellRoute in the top-level list'),
  ];
}

/// The event's id or slug from an `/events/{ref}...` address.
String _eventRef(GoRouterState state) => state.pathParameters['eventRef'] ?? '';

/// The event's own page, for a sub-address of it.
String _eventLocation(GoRouterState state) =>
    '/events/${Uri.encodeComponent(_eventRef(state))}';

/// `/events/{ref}`: the event's page. [EventRefPage] finds the id behind a
/// website slug; the page itself takes the id.
Widget _eventPage(GoRouterState state) {
  final extra = state.extra as Map<String, dynamic>?;
  return EventRefPage(
    eventRef: _eventRef(state),
    page: (eventId) => IndividualEventPage(
      eventId: eventId,
      initialStatus: extra?['status'],
      initialTicketUrl: extra?['ticketUrl'],
      initialCertificateUrl: extra?['certificateUrl'],
      // ?live=quiz|poll|room: a "join now" push, or the website's room.
      openLiveRoom: state.uri.queryParameters.containsKey('live'),
    ),
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
          builder: (context, state) => SignInGate(
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

      // Main shell with bottom nav. The tabs first: Home's pages come
      // last, so `/events/explore` is not taken for an event called
      // "explore".
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
                            final extra =
                                state.extra as Map<String, dynamic>?;
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
                // The features' own routes first: a fixed word in a path
                // ("explore") must win over an event's or a club's slug.
                // Batches A, B and C: one line each, on the marked line.
                ...overHome(rootKey, [
                  // Batch A (discover): ...discoverRoutes,

                  // Batch B (events): ...eventRoutes,

                  // Batch C (clubs, threads, auth, profile): ...clubRoutes,
                ]),
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
                    path: 'events/:eventRef',
                    name: 'eventDetail',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => _eventPage(state),
                    routes: [
                      GoRoute(
                          path: 'register',
                          name: 'eventRegister',
                          parentNavigatorKey: rootKey,
                          // The form needs the event's questions, which
                          // the event page hands over. A link (or a return
                          // from sign-in) has none: it opens the event,
                          // whose Register starts again from there.
                          redirect: (context, state) => state.extra == null
                              ? _eventLocation(state)
                              : null,
                          builder: (context, state) {
                            final extra = state.extra as Map<String, dynamic>?;
                            final additionalDetails =
                                extra?['additionalDetails']
                                        as List<AdditionalDetail>? ??
                                    [];
                            return EventRefPage(
                              eventRef: _eventRef(state),
                              page: (eventId) => EventFormPage(
                                eventId: eventId,
                                additionalDetails: additionalDetails,
                              ),
                            );
                          }),
                      // The website's live room: the event, with the room
                      // open on top (as a "join now" push opens it).
                      GoRoute(
                          path: 'live',
                          redirect: (context, state) =>
                              '${_eventLocation(state)}?live=room'),
                      // The website's team and submission pages: the event,
                      // until the app has its own.
                      GoRoute(
                          path: 'compete',
                          redirect: (context, state) =>
                              _eventLocation(state)),
                    ]),
                // A club, by id or by the website's slug.
                GoRoute(
                    path: 'clubs/:clubRef',
                    name: 'clubDetail',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return ClubRefPage(
                        clubRef: state.pathParameters['clubRef'] ?? '',
                        page: (clubId, slug, name) => ClubIndividualPage(
                          clubId: clubId,
                          clubSlug: extra?['clubSlug'] as String? ?? slug,
                          clubname: extra?['clubName'] as String? ?? name,
                        ),
                      );
                    }),
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
                // A topic: Explore, filtered to it, until there is a topic
                // page (whose route, above, then wins).
                GoRoute(
                    path: 'topics/:topicSlug',
                    redirect: (context, state) => Uri(
                          path: '/events/explore',
                          queryParameters: {
                            'topic': state.pathParameters['topicSlug'] ?? '',
                          },
                        ).toString()),
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
