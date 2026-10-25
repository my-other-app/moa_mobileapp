import 'dart:convert';

import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/core/services/notification_routes.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/pending_notification_route.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The pushes the server sends most -- a followed club's new event, a new
/// event in your topics, the organiser's message, "you're a volunteer",
/// "your certificate is ready" -- and their lines in the inbox, each opening
/// its screen. The payloads are the server's own (moa_backend
/// app/core/notifications/triggers.py): a type and an `event_id` string,
/// no `url`.
const _newEvent = {'type': 'new_event', 'event_id': '12', 'club_id': '5'};
const _interest = {
  'type': 'interest_match',
  'event_id': '12',
  'category_id': '3',
  'push_id': 'nearby_event:12',
};
const _announcement = {
  'type': 'club_announcement',
  'event_id': '12',
  'image_url': '',
};
const _volunteer = {'type': 'volunteer_assigned', 'event_id': '7'};
const _certificate = {'type': 'certificate_generated', 'event_id': '7'};

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

NotificationModel _line(String type,
        {Map<String, dynamic>? event, Map<String, dynamic>? data}) =>
    NotificationModel.fromJson({
      'id': 'n-1',
      'user_id': 1,
      'title': 't',
      'description': '',
      'type': type,
      'status': 'unread',
      'event': event,
      'data': data,
      'created_at': '2026-10-25T08:00:00Z',
    });

void main() {
  group('a tapped push opens its screen (warm start)', () {
    test("a followed club's new event opens the event", () {
      expect(NotificationService.routeFor(_newEvent), '/events/12');
    });

    test('a new event in your topics opens the event', () {
      expect(NotificationService.routeFor(_interest), '/events/12');
      // The type the inbox line has, should a push ever carry it.
      expect(
          NotificationService.routeFor(
              const {'type': 'nearby_event', 'event_id': '12'}),
          '/events/12');
    });

    test("the organiser's message opens the event", () {
      expect(NotificationService.routeFor(_announcement), '/events/12');
    });

    test("you're a volunteer opens the event's door scanner", () {
      expect(NotificationService.routeFor(_volunteer), '/volunteer/scanner/7');
    });

    test('your certificate is ready opens My Certificates', () {
      expect(
          NotificationService.routeFor(_certificate), '/profile/certificates');
      expect(
          NotificationService.routeFor(const {'type': 'certificate_generated'}),
          '/profile/certificates');
    });

    test('registered and invited open the event', () {
      for (final type in ['event_registered', 'event_invited']) {
        expect(
            NotificationService.routeFor({'type': type, 'event_id': '9'}),
            '/events/9',
            reason: type);
      }
    });

    test('a new event that lost its event opens its club', () {
      expect(
          NotificationService.routeFor(
              const {'type': 'new_event', 'club_id': '5'}),
          '/clubs/5');
      expect(NotificationService.routeFor(const {'type': 'new_event'}), isNull);
    });

    test('an event push without its event opens nothing', () {
      for (final type in [
        'interest_match',
        'club_announcement',
        'volunteer_assigned',
      ]) {
        expect(NotificationService.routeFor({'type': type}), isNull,
            reason: type);
        expect(
            NotificationService.routeFor({'type': type, 'event_id': 'x'}),
            isNull,
            reason: type);
      }
    });

    test("the platform's announcement (no type, no url) opens nothing", () {
      expect(
          NotificationService.routeFor(const {'push_id': 'platform:abc'}),
          isNull);
    });
  });

  group('a push that launched the app is held for the splash (cold start)',
      () {
    late PendingNotificationRoute pending;
    setUp(() =>
        pending = PendingNotificationRoute(NotificationService.routeFor));

    for (final (name, data, route) in [
      ('new event', _newEvent, '/events/12'),
      ('interest match', _interest, '/events/12'),
      ('club announcement', _announcement, '/events/12'),
      ('volunteer', _volunteer, '/volunteer/scanner/7'),
      ('certificate', _certificate, '/profile/certificates'),
    ]) {
      test('$name, from the system tray', () {
        pending.hold(data);
        expect(pending.take(), route);
        expect(pending.take(), isNull);
      });

      test('$name, re-shown in the foreground and tapped after', () {
        pending.holdPayload(jsonEncode(data));
        expect(pending.take(), route);
      });
    }
  });

  group('each push and its inbox line open the same screen', () {
    test('new event', () {
      expect(_line('new_event', event: {'id': 12, 'name': 'Hack'}).route,
          NotificationService.routeFor(_newEvent));
    });

    test('nearby event (the push says interest_match)', () {
      expect(_line('nearby_event', event: {'id': 12, 'name': 'Hack'}).route,
          NotificationService.routeFor(_interest));
    });

    test('club announcement', () {
      expect(
          _line('club_announcement', event: {'id': 12, 'name': 'Hack'}).route,
          NotificationService.routeFor(_announcement));
    });

    test('volunteer (the push says volunteer_assigned)', () {
      expect(_line('volunteer_added', event: {'id': 7, 'name': 'Hack'}).route,
          NotificationService.routeFor(_volunteer));
    });

    test('certificate', () {
      expect(
          _line('certificate_generated', event: {'id': 7, 'name': 'H'}).route,
          NotificationService.routeFor(_certificate));
    });

    test("a line without its event reads it from the push's data", () {
      expect(_line('new_event', data: {'event_id': '12'}).route, '/events/12');
      expect(_line('volunteer_added', data: {'event_id': 7}).route,
          '/volunteer/scanner/7');
    });

    test('the route table names every live type the service does', () {
      expect(NotificationService.liveRoomTypes, liveRoomTypes);
      expect(NotificationService.liveJoinRoute(3, 'quiz'),
          liveJoinRoute(3, 'quiz'));
    });
  });

  group("the app's router has a screen for every route a push opens", () {
    late GoRouter router;

    setUp(() {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(
            const AuthState(accessToken: 'token', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      router = container.read(routerProvider);
    });

    for (final (data, name) in [
      (_newEvent, AppRoutes.eventDetail),
      (_interest, AppRoutes.eventDetail),
      (_announcement, AppRoutes.eventDetail),
      (_certificate, AppRoutes.certificates),
      (const {'type': 'new_event', 'club_id': '5'}, AppRoutes.clubDetail),
      (_volunteer, 'volunteerScanner'),
    ]) {
      test('${data['type']} -> $name', () {
        final route = NotificationService.routeFor(data)!;
        final match = router.configuration.findMatch(Uri.parse(route));
        expect(match.isError, isFalse, reason: route);
        expect((match.last.route as GoRoute).name, name);
      });
    }
  });
}
