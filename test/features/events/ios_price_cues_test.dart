import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_page_fixtures.dart';
import 'events_fakes.dart';

// On an iPhone the app doesn't sell a paid online event (canSellInApp), and
// shows no price cue for it either: no fee, no "Paid", no "Payment due", no
// FINISH PAYMENT. Android, in-person and free events keep theirs.

/// A registration from `/events/list?is_registered=true`, waiting for its
/// payment.
Map<String, dynamic> _unpaid({bool online = true, bool paid = true}) => {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2,
      'is_online': online,
      'has_fee': paid,
      'is_paid': false,
      'category': {'id': 1, 'name': 'Tech'},
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
    };

Future<void> _pumpCard(WidgetTester tester, Map<String, dynamic> item) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: eventCardFromJson(item,
            status: EventCardStatus.awaitingPayment),
      ),
    ),
  ));
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('the tags', () {
    test('a paid online event has no "Paid" on iOS, and keeps it elsewhere',
        () {
      final event = _unpaid();
      expect(eventCardTags(event, platform: TargetPlatform.iOS),
          ['Tech', 'Online', '2 Hours']);
      expect(eventCardTags(event, platform: TargetPlatform.android),
          ['Tech', 'Online', 'Paid', '2 Hours']);
      expect(eventCardTags(_unpaid(online: false), platform: TargetPlatform.iOS),
          ['Tech', 'Offline', 'Paid', '2 Hours']);
      expect(eventCardTags(_unpaid(paid: false), platform: TargetPlatform.iOS),
          ['Tech', 'Online', 'Free', '2 Hours']);
    });
  });

  group('an unpaid registration\'s card', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('for a paid online event, on ${platform.name}',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await _pumpCard(tester, _unpaid());

        if (platform == TargetPlatform.iOS) {
          expect(find.text('FINISH PAYMENT'), findsNothing);
          expect(find.byType(PaymentDueBadge), findsNothing);
          expect(find.text('Payment due'), findsNothing);
          expect(find.text('Paid'), findsNothing);
          expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsOneWidget);
          expect(find.text(iosOnlineSaleBlockedMessage), findsOneWidget);
        } else {
          expect(find.text('FINISH PAYMENT'), findsOneWidget);
          expect(find.byType(PaymentDueBadge), findsOneWidget);
          expect(find.text('Paid'), findsOneWidget);
          expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsNothing);
        }
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('for an in-person paid event on iOS: as before',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pumpCard(tester, _unpaid(online: false));

      expect(find.text('FINISH PAYMENT'), findsOneWidget);
      expect(find.byType(PaymentDueBadge), findsOneWidget);
      expect(find.byKey(IosSaleBlockedNotice.noticeKey), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('the event page\'s fee', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('for a paid online event, on ${platform.name}',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        api
          ..on('GET', '/events/info/7',
              eventInfo(hasFee: true, isOnline: true))
          ..on('GET', '/events/7/store/catalog', {
            'enabled': true,
            'items': [
              {
                'id': 'tee',
                'name': 'Hack Night tee',
                'price': 399,
                'variants': [],
              },
            ],
          })
          ..on(
              'GET',
              '/discover/events/7',
              discoverEventPage(
                hasFee: true,
                isOnline: true,
                similar: [
                  {
                    'id': 9,
                    'name': 'Rust Meetup',
                    'is_online': true,
                    'has_fee': true,
                    'fee': 99,
                  },
                ],
              ));
        await _pumpPage(tester);

        if (platform == TargetPlatform.iOS) {
          expect(find.text('Registration Fee'), findsNothing);
          expect(find.text('₹ 250'), findsNothing);
          expect(find.text('On sale with your ticket'), findsNothing);
          expect(find.textContaining('₹'), findsNothing);
          expect(find.text('Online'), findsWidgets);
        } else {
          expect(find.text('Registration Fee'), findsOneWidget);
          expect(find.text('₹ 250'), findsOneWidget);
          expect(find.text('On sale with your ticket'), findsOneWidget);
          expect(find.text('Online · ₹99'), findsOneWidget);
        }
        expect(find.text('Date of Event'), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('an in-person paid event shows its fee on iOS, as before',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      api.on('GET', '/events/info/7', eventInfo(hasFee: true));
      await _pumpPage(tester);

      expect(find.text('Registration Fee'), findsOneWidget);
      expect(find.text('₹ 250'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
