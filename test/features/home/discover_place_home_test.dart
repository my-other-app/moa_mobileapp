// DISCOVER's pill and rails about one place, over the real data source and
// a server that places callers as the backend does.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/datasources/discover_place_store.dart';
import 'package:finnet/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:finnet/features/discover/domain/discover_cities.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/home/presentation/pages/home_page.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../discover/discover_fakes.dart';
import '../discover/place_server.dart';
import '../events/events_fakes.dart';
import '../topics/topic_fixtures.dart';

void main() {
  late PlaceServer server;
  late ApiCache cache;
  late DiscoverPlaceStore places;

  setUp(() {
    server = PlaceServer();
    cache = ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
    places = MemoryDiscoverPlaceStore();
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tallScreen(tester);
    useFakeApi();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = server
      ..interceptors.addAll([ApiCacheInterceptor(cache), ErrorInterceptor()]);
    final c = ProviderContainer(overrides: [
      discoverRemoteDataSourceProvider
          .overrideWithValue(DiscoverRemoteDataSourceImpl(dio, cache: cache)),
      discoverPlaceStoreProvider.overrideWithValue(places),
      isAuthenticatedProvider.overrideWithValue(false),
      topicDirectoryProvider.overrideWith((ref) => Stream.value(catalogue)),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: HomePage())),
    ));
    await settle(tester);
    return c;
  }

  Finder place() => find.byKey(const ValueKey('discover-home-place'));
  Finder nearRail(String name) => find.descendant(
      of: find.byKey(const ValueKey('rail-near')), matching: find.text(name));
  String placeText(WidgetTester tester) => tester.widget<Text>(place()).data!;

  testWidgets('a new place: the old place\'s rails are not drawn under it',
      (tester) async {
    final c = await pump(tester);
    expect(placeText(tester), 'Near Thiruvananthapuram');
    expect(find.text('Neural Tide Demo Day'), findsWidgets);

    final held = Completer<void>();
    server.holdHome = held.future;
    c
        .read(discoverPlaceProvider.notifier)
        .pick(discoverCities.firstWhere((x) => x.slug == 'kochi'));
    await settle(tester);

    // Kochi's page is on its way: Thiruvananthapuram's is not shown.
    expect(find.byKey(const ValueKey('discover-home-loading')), findsOneWidget);
    expect(find.text('Neural Tide Demo Day'), findsNothing);
    expect(find.text('Near Thiruvananthapuram'), findsNothing);

    held.complete();
    server.holdHome = null;
    await settle(tester);
    expect(placeText(tester), 'Near Kochi');
    expect(nearRail('Profiling in Production'), findsOneWidget);
  });

  testWidgets('offline after picking: an error, never the old place',
      (tester) async {
    final c = await pump(tester);
    expect(placeText(tester), 'Near Thiruvananthapuram');

    server.offline = true;
    c
        .read(discoverPlaceProvider.notifier)
        .pick(discoverCities.firstWhere((x) => x.slug == 'kochi'));
    await settle(tester);

    expect(find.byKey(const ValueKey('discover-home-error')), findsOneWidget);
    expect(find.text('Near Thiruvananthapuram'), findsNothing);
    expect(find.text('Neural Tide Demo Day'), findsNothing);
  });

  testWidgets('picked on the pill, kept at the next launch on any network',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('discover-home-where')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('discover-where-city-kochi')));
    await settle(tester);
    expect(placeText(tester), 'Near Kochi');
    expect(nearRail('Profiling in Production'), findsOneWidget);
    expect(nearRail('Neural Tide Demo Day'), findsNothing);

    // The app starts again, on mobile data.
    await tester.pumpWidget(const SizedBox());
    server.ip = ipMumbai;
    await pump(tester);
    expect(placeText(tester), 'Near Kochi');
    expect(nearRail('Profiling in Production'), findsOneWidget);
  });
}
