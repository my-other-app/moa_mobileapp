import 'dart:io';

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/services/notification_routes.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/events_routes.dart';
import 'package:finnet/features/events/presentation/pages/claim_offer_page.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

/// The event routes as the app has them, the claim link's among them.
GoRouter _router(String location) => GoRouter(
      initialLocation: location,
      routes: [
        ...eventsRoutes,
        GoRoute(
          path: '/events/:eventId',
          builder: buildEventPage,
          routes: [
            GoRoute(path: 'register', builder: buildEventRegisterPage),
          ],
        ),
      ],
    );

Future<void> _open(WidgetTester tester, String location) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: MaterialApp.router(routerConfig: _router(location)),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('the claim link', () {
    test('the website\'s address opens the claim screen', () {
      expect(webLocation(Uri.parse('https://myotherapp.in/claim/Xy3_abc')),
          '/claim/Xy3_abc');
      expect(appLocationForLink(Uri.parse('https://myotherapp.in/claim/Xy3')),
          '/claim/Xy3');
      // www. redirects to the apex: the same screen.
      expect(webLocation(Uri.parse('https://www.myotherapp.in/claim/Xy3')),
          '/claim/Xy3');
      expect(webLocation(Uri.parse('https://myotherapp.in/claim')), isNull);
      expect(webLocation(Uri.parse('https://myotherapp.in/claim/a/b')), isNull);
    });

    test('it needs no account: the token is the proof', () {
      expect(needsAccount('/claim/Xy3'), isFalse);
    });

    test('Android opens it in the app (an App Link path)', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:pathPrefix="/claim/"'));
    });

    testWidgets('/claim/{token} is the claim screen for that token',
        (tester) async {
      final api = useFakeApi();
      await _open(tester, '/claim/tok_1');

      final page = tester.widget<ClaimOfferPage>(find.byType(ClaimOfferPage));
      expect(page.token, 'tok_1');
      expect(api.sent('GET', '/waitlist/offers/tok_1'), hasLength(1));
    });
  });

  group('the waiting list offer push', () {
    test('opens the claim screen by its token', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'waitlist_offer',
          'event_id': '7',
          'url': 'https://myotherapp.in/claim/tok_1',
          'token': 'tok_1',
        }),
        '/claim/tok_1',
      );
    });

    test('or by the token in its link', () {
      expect(
        notificationRoute(waitlistOfferType,
            eventId: 7, data: const {'url': 'https://myotherapp.in/claim/tok_2'}),
        '/claim/tok_2',
      );
    });

    test('with neither, the event', () {
      expect(notificationRoute(waitlistOfferType, eventId: 7), '/events/7');
      expect(notificationRoute(waitlistOfferType), isNull);
    });

    test('its line in the inbox opens the same screen', () {
      final line = NotificationModel.fromJson({
        'id': 'n-1',
        'user_id': 1,
        'title': 'A place opened up for Hack Night',
        'description': '',
        'type': 'waitlist_offer',
        'status': 'unread',
        'event': {'id': 7, 'name': 'Hack Night'},
        'data': {'token': 'tok_3', 'url': 'https://myotherapp.in/claim/tok_3'},
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(line.route, '/claim/tok_3');
    });
  });

  group('a link to a hidden ticket type', () {
    testWidgets('the event page shows it', (tester) async {
      useFakeApi();
      await _open(tester, '/events/hack-night?ticket_type=30');
      final page =
          tester.widget<IndividualEventPage>(find.byType(IndividualEventPage));
      expect(page.linkedTicketTypeId, 30);
    });

    testWidgets('the form chooses it', (tester) async {
      useFakeApi();
      await _open(tester, '/events/hack-night/register?ticket_type=30');
      final form = tester.widget<EventFormPage>(find.byType(EventFormPage));
      expect(form.linkedTicketTypeId, 30);
    });
  });
}
