import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/pages/contact_us_page.dart';
import 'package:finnet/features/support/presentation/pages/help_page.dart';
import 'package:finnet/features/support/presentation/pages/my_requests_page.dart';
import 'package:finnet/features/support/presentation/pages/support_request_page.dart';

/// The help screens' addresses. Under `/profile`, so signed in only
/// (route_access.dart): a `support_reply` push tapped signed out asks for
/// sign-in, then opens the request.
class SupportLocations {
  SupportLocations._();

  static const help = '/profile/help';
  static const contact = '/profile/help/contact';
  static const requests = '/profile/help/requests';
  static String request(String id) => supportRequestRoute(id);
}

class SupportRouteNames {
  SupportRouteNames._();

  static const help = 'help';
  static const contact = 'helpContact';
  static const requests = 'helpRequests';
  static const request = 'helpRequest';
}

/// Help and support, as sub-routes of `/profile` on the root navigator
/// (over the tabs, as Settings is).
List<RouteBase> supportRoutes(GlobalKey<NavigatorState> rootKey) => [
      GoRoute(
        path: 'help',
        name: SupportRouteNames.help,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const HelpPage(),
        routes: [
          // `?topic=` and `?event=` start the form on them.
          GoRoute(
            path: 'contact',
            name: SupportRouteNames.contact,
            parentNavigatorKey: rootKey,
            builder: (context, state) => ContactUsPage(
              initialTopic: state.uri.queryParameters['topic'],
              initialEventId:
                  int.tryParse(state.uri.queryParameters['event'] ?? ''),
            ),
          ),
          GoRoute(
            path: 'requests',
            name: SupportRouteNames.requests,
            parentNavigatorKey: rootKey,
            builder: (context, state) => const MyRequestsPage(),
            routes: [
              GoRoute(
                path: ':caseId',
                name: SupportRouteNames.request,
                parentNavigatorKey: rootKey,
                builder: (context, state) => SupportRequestPage(
                  caseId: state.pathParameters['caseId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    ];
