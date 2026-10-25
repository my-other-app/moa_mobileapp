import 'package:finnet/features/live/live_locations.dart';
import 'package:finnet/features/live/presentation/pages/live_room_page.dart';
import 'package:finnet/features/live/presentation/pages/quiz_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:finnet/features/live/live_locations.dart';

// The live room's routes, under the event's (app_router.dart):
//
// - `/events/{ref}/live` -- the room: updates, the poll, questions, the quiz
//   entry. The website's address too, so its links (and the QR codes on the
//   screen) open it.
// - `/events/{ref}/live/quiz` -- the quiz: join with the code, then play.
//
// `{ref}` is the event's id or slug. Both are open without an account, as
// on the website.

String _refOf(GoRouterState state) {
  final params = state.pathParameters;
  return (params['eventId'] ?? params['eventRef'] ?? '').trim();
}

String? _nameOf(GoRouterState state) {
  final extra = state.extra;
  return extra is Map && extra['eventName'] is String
      ? extra['eventName'] as String
      : null;
}

/// `/events/:eventId/live`. extra: `eventName`, shown while the room loads.
Widget buildLiveRoomPage(BuildContext context, GoRouterState state) {
  final ref = _refOf(state);
  return LiveRoomPage(
    key: ValueKey('live-$ref'),
    eventRef: ref,
    eventName: _nameOf(state),
  );
}

/// `/events/:eventId/live/quiz`.
Widget buildQuizPage(BuildContext context, GoRouterState state) {
  final ref = _refOf(state);
  return QuizPage(
    key: ValueKey('quiz-$ref'),
    eventRef: ref,
    eventName: _nameOf(state),
  );
}

/// The event's page asked to open its room (`/events/{ref}?live=quiz`, what
/// pushes and the website's links said before the room was in the app):
/// the room itself now, or the quiz for `live=quiz`. Anything else is left.
String? legacyLiveRedirect(BuildContext context, GoRouterState state) {
  final uri = state.uri;
  final kind = uri.queryParameters['live'];
  if (kind == null) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 2 || segments.first.toLowerCase() != 'events') {
    return null;
  }
  final rest = Map<String, String>.of(uri.queryParameters)..remove('live');
  final path = kind == 'quiz'
      ? liveQuizLocation(segments[1])
      : liveRoomLocation(segments[1]);
  return Uri(path: path, queryParameters: rest.isEmpty ? null : rest)
      .toString();
}

/// Opens the room (or, with [quiz], the quiz) for [ref] on top of what is
/// showing, so Back comes back here. Through the router when there is one;
/// a plain route otherwise (a screen shown on its own).
Future<void> openLiveRoom(
  BuildContext context,
  Object ref, {
  String? eventName,
  bool quiz = false,
}) async {
  final router = GoRouter.maybeOf(context);
  final extra = {if (eventName != null) 'eventName': eventName};
  if (router != null) {
    await router.push<void>(
      quiz ? liveQuizLocation(ref) : liveRoomLocation(ref),
      extra: extra,
    );
    return;
  }
  await Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => quiz
        ? QuizPage(eventRef: '$ref', eventName: eventName)
        : LiveRoomPage(eventRef: '$ref', eventName: eventName),
  ));
}
