import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

/// An upcoming event the person hasn't registered for.
Map<String, dynamic> _event({bool hasFee = true, bool isOnline = false}) => {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'poster': null,
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': hasFee,
      'reg_fee': 250,
      'has_prize': false,
      'is_online': isOnline,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': null,
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': {}},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': <dynamic>[],
      'rating': 0,
      'total_rating': 0,
      'is_registered': false,
      'is_attended': false,
    };

const _catalog = {
  'enabled': true,
  'items': [
    {
      'id': 'tee',
      'name': 'Hack Night tee',
      'price': 450,
      'left': null,
      'variants': [
        {'id': 's', 'label': 'S', 'left': 2},
        {'id': 'm', 'label': 'M', 'left': 30},
      ],
    },
    {
      'id': 'kit',
      'name': 'Starter kit',
      'price': 1890,
      'left': 4,
      'variants': <dynamic>[],
    },
    {
      'id': 'sticker',
      'name': 'Sticker pack',
      'price': 0,
      'left': 200,
      'variants': <dynamic>[],
    },
  ],
};

const _heading = 'On sale with your ticket';

Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
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
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets(
      'what the event sells with its ticket: names, sizes and prices, '
      'with free ones saying so', (tester) async {
    api
      ..on('GET', '/events/info/7', _event())
      ..on('GET', '/events/7/store/catalog', _catalog);
    await _pump(tester);

    expect(api.sent('GET', '/events/7/store/catalog'), hasLength(1));
    // Asked for without the person's token: the shelf is the same for all.
    expect(
        api.sent('GET', '/events/7/store/catalog').single.extra['skipAuth'],
        isTrue);
    expect(find.text(_heading), findsOneWidget);
    expect(find.text('Pick these when you register and pay once.'),
        findsOneWidget);
    expect(find.text('Hack Night tee'), findsOneWidget);
    expect(find.text('S · M'), findsOneWidget);
    expect(find.text('₹450'), findsOneWidget);
    expect(find.text('Starter kit'), findsOneWidget);
    expect(find.text('₹1,890'), findsOneWidget);
    expect(find.text('Sticker pack'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('a shop that is switched off, or empty, shows nothing',
      (tester) async {
    api
      ..on('GET', '/events/info/7', _event())
      ..on('GET', '/events/7/store/catalog',
          {'enabled': false, 'items': _catalog['items']});
    await _pump(tester);
    expect(find.text(_heading), findsNothing);
  });

  testWidgets('no shop at all (a 404) shows nothing, and the event loads',
      (tester) async {
    api.on('GET', '/events/info/7', _event());
    await _pump(tester);

    expect(find.text(_heading), findsNothing);
    expect(find.text('Hack Night'), findsWidgets);
  });

  testWidgets(
      'on an iPhone, a paid online event sells nothing here: no shelf '
      'either', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    api
      ..on('GET', '/events/info/7', _event(isOnline: true))
      ..on('GET', '/events/7/store/catalog', _catalog);
    await _pump(tester);

    expect(find.text(_heading), findsNothing);
    expect(find.text('Hack Night tee'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on an iPhone, an event at a venue still shows its shelf',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    api
      ..on('GET', '/events/info/7', _event())
      ..on('GET', '/events/7/store/catalog', _catalog);
    await _pump(tester);

    expect(find.text(_heading), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on Android, a paid online event shows its shelf',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    api
      ..on('GET', '/events/info/7', _event(isOnline: true))
      ..on('GET', '/events/7/store/catalog', _catalog);
    await _pump(tester);

    expect(find.text(_heading), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
