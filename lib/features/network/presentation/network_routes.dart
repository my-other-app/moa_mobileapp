import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/features/network/presentation/pages/code_save_page.dart';
import 'package:finnet/features/network/presentation/pages/edit_public_profile_page.dart';
import 'package:finnet/features/network/presentation/pages/my_qr_page.dart';
import 'package:finnet/features/network/presentation/pages/network_page.dart';
import 'package:finnet/features/network/presentation/pages/network_person_page.dart';
import 'package:finnet/features/network/presentation/pages/public_profile_page.dart';
import 'package:finnet/features/network/presentation/pages/save_person_scanner_page.dart';
import 'package:finnet/features/network/presentation/pages/saved_me_page.dart';
import 'package:finnet/features/network/presentation/pages/stranger_preview_page.dart';

int? _eventIn(GoRouterState state) =>
    int.tryParse(state.uri.queryParameters['event'] ?? '');

/// A profile and a personal QR's link, at the website's addresses so a
/// link or a camera opens them here as they are: open without an account
/// (saving asks for one). Re-rooted over Home by the router (`overHome`).
final List<RouteBase> profileLinkRoutes = [
  GoRoute(
    path: '/u/:handle',
    name: 'publicProfile',
    builder: (context, state) => PublicProfilePage(
      handle: state.pathParameters['handle'] ?? '',
      // The website's "Save to your network": the Save offer first.
      saveIntent: const {'1', 'true'}
          .contains(state.uri.queryParameters['save']?.toLowerCase()),
    ),
  ),
  GoRoute(
    path: '/p/:code',
    name: 'profileCode',
    builder: (context, state) =>
        CodeSavePage(code: state.pathParameters['code'] ?? ''),
  ),
];

/// Under `/profile`, on the root navigator: My QR, and editing the public
/// profile with its stranger's preview. Signed in only, as all of
/// `/profile` is (route_access.dart).
List<RouteBase> myNetworkProfileRoutes(GlobalKey<NavigatorState> rootKey) => [
      GoRoute(
        path: 'qr',
        name: 'myQr',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const MyQrPage(),
      ),
      GoRoute(
        path: 'public',
        name: 'editPublicProfile',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const EditPublicProfilePage(),
        routes: [
          GoRoute(
            path: 'preview',
            name: 'strangerPreview',
            parentNavigatorKey: rootKey,
            builder: (context, state) => const StrangerPreviewPage(),
          ),
        ],
      ),
    ];

/// The Network tab (in the bottom bar's shell), and its pages above it on
/// the root navigator: the scanner's "Save a person" mode, who saved the
/// person, and one person. Signed in only (route_access.dart).
GoRoute networkTabRoute(GlobalKey<NavigatorState> rootKey) => GoRoute(
      path: '/network',
      name: 'network',
      builder: (context, state) => NetworkPage(
        // Keyed by the event, so the recap's link opens at its event even
        // when the tab is already open.
        key: ValueKey('network-${_eventIn(state)}'),
        eventId: _eventIn(state),
      ),
      routes: [
        GoRoute(
          path: 'scan',
          name: 'savePersonScan',
          parentNavigatorKey: rootKey,
          builder: (context, state) =>
              SavePersonScannerPage(eventId: _eventIn(state)),
        ),
        GoRoute(
          path: 'saved-me',
          name: 'savedMe',
          parentNavigatorKey: rootKey,
          builder: (context, state) => SavedMePage(eventId: _eventIn(state)),
        ),
        GoRoute(
          path: ':id',
          name: 'networkPerson',
          parentNavigatorKey: rootKey,
          builder: (context, state) => NetworkPersonPage(
              id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
        ),
      ],
    );
