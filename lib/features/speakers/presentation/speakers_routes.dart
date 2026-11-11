import 'package:go_router/go_router.dart';

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
