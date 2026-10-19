import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/pages/clubs_directory_page.dart';
import 'package:finnet/features/discover/presentation/pages/find_events_page.dart';
import 'package:finnet/features/discover/presentation/pages/threads_feed_page.dart';
import 'package:finnet/features/topics/presentation/pages/topic_page.dart';
import 'package:finnet/features/topics/presentation/pages/topics_page.dart';

export 'package:finnet/features/discover/presentation/discover_navigation.dart';

/// Batch A's screens, spread into the app's router. Full-screen pages over
/// the tabs, each readable signed out (the router decides who may open
/// them).
///
/// | Address | Screen | The website's |
/// | --- | --- | --- |
/// | `/discover/events?q&when&from&to&type&price&category&topic&interest&sort&radius_km&near=1&view=calendar&month` | Find events (list or calendar) | `/events?…` |
/// | `/discover/clubs?q&topic&interest&sort&radius_km&near=1` | Find clubs | `/clubs?…` |
/// | `/discover/threads` | From the clubs (every club's posts) | `/threads` |
/// | `/topics` | Topics | `/topics` |
/// | `/topics/:slug?interest=` | A topic | `/topics/{slug}` |
///
/// The website's `near=lat,lng` is read as "near the person": the app sends
/// no coordinates.
List<RouteBase> get discoverRoutes => [
      GoRoute(
        path: findEventsPath,
        name: 'findEvents',
        builder: (context, state) =>
            FindEventsPage.fromParams(state.uri.queryParameters),
      ),
      GoRoute(
        path: clubsDirectoryPath,
        name: 'clubsDirectory',
        builder: (context, state) =>
            ClubsDirectoryPage.fromParams(state.uri.queryParameters),
      ),
      GoRoute(
        path: threadsFeedPath,
        name: 'threadsFeed',
        builder: (context, state) => const ThreadsFeedPage(),
      ),
      GoRoute(
        path: topicsPath,
        name: 'topics',
        builder: (context, state) => const TopicsPage(),
        routes: [
          GoRoute(
            path: ':slug',
            name: 'topic',
            builder: (context, state) => TopicPage(
              slug: state.pathParameters['slug'] ?? '',
              interest: int.tryParse(state.uri.queryParameters['interest'] ?? ''),
            ),
          ),
        ],
      ),
    ];

/// The addresses above that need no account, for the router's signed-out
/// rule (batch D): every one of them.
bool isDiscoverLocation(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  return path == findEventsPath ||
      path == clubsDirectoryPath ||
      path == threadsFeedPath ||
      path == topicsPath ||
      path.startsWith('$topicsPath/');
}
