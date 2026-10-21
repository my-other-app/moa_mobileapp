// Where the discover lists are about, across networks and launches: the
// owner saw "nearby places and some other places, sometimes". Each test
// below failed before the app kept one place and sent its point.

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/discover/data/datasources/discover_place_store.dart';
import 'package:finnet/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:finnet/features/discover/domain/discover_cities.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'place_server.dart';

void main() {
  late PlaceServer server;
  late MemoryCacheStore shared;
  late ApiCache cache;
  late DiscoverPlaceStore places;

  setUp(() {
    server = PlaceServer();
    shared = MemoryCacheStore();
    cache = ApiCache(shared: shared, personal: MemoryCacheStore());
    places = MemoryDiscoverPlaceStore();
  });

  /// The app started: a fresh set of providers over the same phone (the
  /// saved answers, the kept place).
  ProviderContainer launch() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = server
      ..interceptors.addAll([ApiCacheInterceptor(cache), ErrorInterceptor()]);
    final c = ProviderContainer(overrides: [
      discoverRemoteDataSourceProvider
          .overrideWithValue(DiscoverRemoteDataSourceImpl(dio, cache: cache)),
      discoverPlaceStoreProvider.overrideWithValue(places),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> turns([int n = 30]) async {
    for (var i = 0; i < n; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Every front page the screen would draw, in order, once all is in.
  Future<List<DiscoverHome>> homes(ProviderContainer c) async {
    final seen = <DiscoverHome>[];
    final sub =
        c.listen<AsyncValue<DiscoverHome>>(discoverHomeProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null && !next.isLoading && (seen.isEmpty || seen.last != v)) {
        seen.add(v);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);
    await turns();
    return seen;
  }

  List<String> names(Iterable<dynamic> items) =>
      [for (final i in items) i.name as String];

  const tvmEvents = ['Neural Tide Demo Day', "Founders' Dinner"];

  test('pulled again on another network, the place stays', () async {
    final c = launch();
    final first = (await homes(c)).last;
    expect(first.where.city, 'Thiruvananthapuram');
    expect(names(first.near), tvmEvents);

    // Wi-Fi to mobile data: the carrier's address is in Mumbai.
    server.ip = ipMumbai;
    c.invalidate(discoverHomeProvider);
    final again = (await homes(c)).last;

    expect(again.where.city, 'Thiruvananthapuram');
    expect(names(again.near), tvmEvents);
  });

  test('a launch on another network: no flip from one place to another',
      () async {
    final first = launch();
    expect((await homes(first)).last.where.city, 'Thiruvananthapuram');
    first.dispose();

    server.ip = ipMumbai;
    final drawn = await homes(launch());

    // The saved copy and the fresh answer are the same place.
    expect([for (final h in drawn) h.where.city],
        everyElement('Thiruvananthapuram'));
    expect([for (final h in drawn) names(h.near)], everyElement(tvmEvents));
  });

  test("See all near you lists what is near the pill's place", () async {
    final c = launch();
    expect((await homes(c)).last.where.city, 'Thiruvananthapuram');

    server.ip = ipMumbai;
    const near =
        EventFilters(place: DiscoverPlace.near, sort: EventSort.distance);
    final sub = c.listen(eventSearchProvider(near), (_, __) {});
    addTearDown(sub.close);
    await turns();
    final list = c.read(eventSearchProvider(near));

    expect(list.meta?.where.city, 'Thiruvananthapuram');
    expect(names(list.items), tvmEvents);

    const clubsNear =
        ClubFilters(place: DiscoverPlace.near, sort: ClubSort.nearby);
    final clubsSub = c.listen(clubSearchProvider(clubsNear), (_, __) {});
    addTearDown(clubsSub.close);
    await turns();
    expect(names(c.read(clubSearchProvider(clubsNear)).items), ['Neural Tide']);
  });

  test('the first launch asks without a point; after, the kept one goes',
      () async {
    final c = launch();
    await homes(c);
    c.invalidate(discoverHomeProvider);
    await homes(c);

    final sent = server.sent('/discover/home');
    expect(sent.first.queryParameters, isEmpty);
    expect(sent.last.queryParameters, {'lat': 8.483, 'lng': 76.917});
  });

  test('a picked city beats the connection, and outlasts the launch', () async {
    final c = launch();
    await homes(c);
    c
        .read(discoverPlaceProvider.notifier)
        .pick(discoverCities.firstWhere((x) => x.slug == 'kochi'));
    final picked = (await homes(c)).last;
    expect(picked.where.city, 'Kochi');
    expect(names(picked.near), ['Profiling in Production']);
    c.dispose();

    // Next launch, the connection says Thiruvananthapuram again.
    final next = (await homes(launch())).last;
    expect(next.where.city, 'Kochi');
    expect(next.where.explanation, 'You picked Kochi.');
    expect(names(next.near), ['Profiling in Production']);
  });

  test("a list's saved copy is kept for its place", () async {
    final c = launch();
    await homes(c);
    c.invalidate(discoverHomeProvider);
    await homes(c);
    final keys = shared.values.keys.where((k) => k.contains('home')).toList()
      ..sort();
    expect(keys, [
      'GET /api/v1/discover/home',
      'GET /api/v1/discover/home?lat=8.483&lng=76.917',
    ]);
  });

  test('events near you are near: no online events padding the list', () async {
    final c = launch();
    const near = EventFilters(place: DiscoverPlace.near);
    final sub = c.listen(eventSearchProvider(near), (_, __) {});
    addTearDown(sub.close);
    await turns();
    final list = c.read(eventSearchProvider(near));

    expect(names(list.items), tvmEvents);
    expect(list.total, 2);
  });
}
