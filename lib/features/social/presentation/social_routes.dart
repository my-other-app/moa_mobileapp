import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/features/social/presentation/pages/share_kit_pages.dart';

/// The share kits, as sub-routes of `/profile` on the root navigator: for
/// a club's team members, so signed in only (route_access.dart). A
/// `share_kit` push tapped signed out asks for sign-in, then opens the kit.
List<RouteBase> socialRoutes(GlobalKey<NavigatorState> rootKey) => [
      GoRoute(
        path: 'share-kits',
        name: 'shareKits',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const ShareKitsPage(),
        routes: [
          GoRoute(
            path: ':eventId',
            name: 'shareKit',
            parentNavigatorKey: rootKey,
            builder: (context, state) => ShareKitPage(
              eventId: int.tryParse(state.pathParameters['eventId'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
    ];
