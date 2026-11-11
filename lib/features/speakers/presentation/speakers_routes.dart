import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/features/speakers/presentation/pages/followed_speakers_page.dart';
import 'package:finnet/features/speakers/presentation/pages/speaker_page.dart';

/// The speakers directory's routes: a speaker's page, open without an
/// account (following asks for one), at the website's address so its link
/// opens here as it is. Re-rooted over Home by the router (`overHome`).
final List<RouteBase> speakersRoutes = [
  GoRoute(
    path: '/speakers/:slug',
    name: 'speaker',
    builder: (context, state) =>
        SpeakerPage(slug: state.pathParameters['slug'] ?? ''),
  ),
];

/// Profile > Speakers I Follow, as a sub-route of `/profile` on the root
/// navigator ([followedSpeakersLocation]): signed in only, as all of
/// `/profile` is (route_access.dart).
List<RouteBase> followedSpeakersRoutes(GlobalKey<NavigatorState> rootKey) => [
      GoRoute(
        path: 'speakers',
        name: 'followedSpeakers',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const FollowedSpeakersPage(),
      ),
    ];
