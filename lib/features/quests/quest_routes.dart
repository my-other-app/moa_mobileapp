import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/features/quests/presentation/pages/quest_page.dart';

export 'package:finnet/features/quests/quest_links.dart';

/// `/events/:eventRef/quest`: the guest's quest at an event, in full. Open
/// without an account (the tasks and rewards, as on the website; progress
/// once signed in). extra: `eventName`, shown over the card.
final List<RouteBase> questRoutes = [
  GoRoute(
    path: '/events/:eventRef/quest',
    name: 'eventQuest',
    builder: (context, state) {
      final ref = (state.pathParameters['eventRef'] ?? '').trim();
      final extra = state.extra is Map ? state.extra as Map : const {};
      return QuestPage(
        key: ValueKey('quest-$ref'),
        eventRef: ref,
        eventName:
            extra['eventName'] is String ? extra['eventName'] as String : null,
      );
    },
  ),
];
