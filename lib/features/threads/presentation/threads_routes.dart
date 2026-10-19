import 'package:go_router/go_router.dart';
import 'package:finnet/features/threads/presentation/pages/following_threads_page.dart';

/// Batch C's Threads routes.
///
/// Not under `/threads/`: `/threads/:threadId` (a post) would read
/// "following" as a post's id, whichever way the router orders them.
final List<RouteBase> threadsRoutes = [
  // Posts from the clubs you follow (`/threads/feed`), from the Clubs tab.
  // Signed out it asks the person to sign in.
  GoRoute(
    path: '/following/posts',
    name: 'followingPosts',
    builder: (context, state) => const FollowingThreadsPage(),
  ),
];
