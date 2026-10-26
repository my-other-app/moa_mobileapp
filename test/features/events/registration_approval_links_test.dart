import 'dart:convert';
import 'dart:io';

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/services/notification_routes.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/pending_notification_route.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/events_routes.dart';
import 'package:finnet/features/events/presentation/pages/registration_request_page.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

/// A request push's data, as the server sends it: strings throughout.
Map<String, dynamic> _push(String type,
        [Map<String, dynamic> more = const {}]) =>
    {'type': type, 'event_id': '7', 'token': 'tok_1', ...more};

void main() {
  group('the request link', () {
    test('the website\'s address opens the request\'s screen', () {
      expect(webLocation(Uri.parse('https://myotherapp.in/requests/Xy3_abc')),
          '/requests/Xy3_abc');
      expect(
          appLocationForLink(Uri.parse('https://www.myotherapp.in/requests/a')),
          '/requests/a');
      expect(webLocation(Uri.parse('https://myotherapp.in/requests')), isNull);
      expect(
          webLocation(Uri.parse('https://myotherapp.in/requests/a/b')), isNull);
    });

    test('it needs no account: the token is the proof', () {
      expect(needsAccount('/requests/Xy3'), isFalse);
      // The form's answer is the signed-in person's own.
      expect(needsAccount('/events/request-sent'), isTrue);
    });

    test('Android opens it in the app (an App Link path)', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:pathPrefix="/requests/"'));
      expect(manifest, contains('android:pathPrefix="/claim/"'));
    });

    testWidgets('/requests/{token} is the request\'s screen; ?next=pay pays',
        (tester) async {
      final api = useFakeApi();
      Future<RegistrationRequestPage> open(String location) async {
        await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [isAuthenticatedProvider.overrideWithValue(false)],
          child: MaterialApp.router(
              routerConfig:
                  GoRouter(initialLocation: location, routes: eventsRoutes)),
        ));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        return tester.widget<RegistrationRequestPage>(
            find.byType(RegistrationRequestPage));
      }

      final page = await open('/requests/tok_1');
      expect(page.token, 'tok_1');
      expect(page.openPay, isFalse);
      expect(api.sent('GET', '/registration-requests/tok_1'), hasLength(1));

      expect((await open('/requests/tok_2?next=pay')).openPay, isTrue);
    });
  });

  group('the request pushes', () {
    test('confirmed, with its ticket: the ticket', () {
      expect(
          NotificationService.routeFor(
              _push('request_approved', {'ticket_id': 'T-9'})),
          '/tickets/T-9');
    });

    test('confirmed, no ticket id yet: the request\'s screen', () {
      expect(NotificationService.routeFor(_push('request_approved')),
          '/requests/tok_1');
      // The server sends an empty `ticket_id` when there is none yet.
      expect(
          NotificationService.routeFor(
              _push('request_approved', {'ticket_id': ''})),
          '/requests/tok_1');
      // Or by the token in its link.
      expect(
          NotificationService.routeFor({
            'type': 'request_approved',
            'event_id': '7',
            'url': 'https://myotherapp.in/requests/tok_2',
          }),
          '/requests/tok_2');
    });

    test('confirmed, to pay: the claim screen', () {
      expect(
          NotificationService.routeFor(
              _push('request_approved_pay', {'claim_token': 'clm_1'})),
          '/claim/clm_1');
      expect(
          NotificationService.routeFor(_push('request_approved_pay',
              {'url': 'https://myotherapp.in/claim/clm_2'})),
          '/claim/clm_2');
      // As the server sends it: `url` the request's, `claim_url` the claim's.
      expect(
          NotificationService.routeFor(_push('request_approved_pay', {
            'url': 'https://myotherapp.in/requests/tok_1',
            'claim_url': 'https://myotherapp.in/claim/clm_3',
          })),
          '/claim/clm_3');
      // Only the request's token: its screen, told to go on to paying.
      expect(NotificationService.routeFor(_push('request_approved_pay')),
          '/requests/tok_1?next=pay');
    });

    test('declined: the request\'s screen', () {
      expect(NotificationService.routeFor(_push('request_declined')),
          '/requests/tok_1');
    });

    test('without a token: the event; without either: nothing', () {
      for (final type in requestTypes) {
        expect(notificationRoute(type, eventId: 7), '/events/7', reason: type);
        expect(notificationRoute(type), isNull, reason: type);
      }
    });

    test('tapped while the app was closed: held, then opened once', () {
      final launch = PendingNotificationRoute(NotificationService.routeFor)
        ..hold(_push('request_declined'));
      expect(launch.take(), '/requests/tok_1');
      expect(launch.take(), isNull);

      // A push shown while the app was open, tapped after it closed.
      final local = PendingNotificationRoute(NotificationService.routeFor)
        ..holdPayload(jsonEncode(
            _push('request_approved_pay', {'claim_token': 'clm_1'})));
      expect(local.take(), '/claim/clm_1');
    });

    test('their lines in the inbox open the same screens', () {
      NotificationModel line(String type, Map<String, dynamic> data) =>
          NotificationModel.fromJson({
            'id': 'n-1',
            'user_id': 1,
            'title': 'Tinkerhub confirmed your place',
            'description': '',
            'type': type,
            'status': 'unread',
            'event': {'id': 7, 'name': 'Hack Night'},
            'data': data,
            'created_at': DateTime.now().toIso8601String(),
          });

      expect(line('request_approved', {'token': 'tok_3'}).route,
          '/requests/tok_3');
      expect(
          line('request_approved', {'token': 'tok_3', 'ticket_id': 'T-3'})
              .route,
          '/tickets/T-3');
      expect(
          line('request_approved_pay', {'token': 'tok_3', 'claim_token': 'c3'})
              .route,
          '/claim/c3');
      expect(line('request_declined', {'token': 'tok_3'}).route,
          '/requests/tok_3');
      // No token in the line: its event.
      expect(line('request_declined', const {}).route, '/events/7');
    });

    test('the waiting list\'s offer is as it was', () {
      expect(
          NotificationService.routeFor(const {
            'type': 'waitlist_offer',
            'event_id': '7',
            'token': 'tok_1',
          }),
          '/claim/tok_1');
    });
  });
}
