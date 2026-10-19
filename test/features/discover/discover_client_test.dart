import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show RouteAdapter;
import 'discover_fixtures.dart';

/// [RouteAdapter], but able to drop off the network.
class _Api extends RouteAdapter {
  bool offline = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    if (offline) {
      requests.add(options);
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  late _Api api;
  late MemoryCacheStore shared;
  late ApiCache cache;
  late ProviderContainer container;

  setUp(() {
    api = _Api();
    shared = MemoryCacheStore();
    cache = ApiCache(shared: shared, personal: MemoryCacheStore());
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = api
      ..interceptors.addAll([ApiCacheInterceptor(cache), ErrorInterceptor()]);
    container = ProviderContainer(overrides: [
      discoverRemoteDataSourceProvider
          .overrideWithValue(DiscoverRemoteDataSourceImpl(dio, cache: cache)),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<EventSearchState> loaded(EventFilters filters) async {
    container.listen(eventSearchProvider(filters), (_, __) {});
    for (var i = 0; i < 20; i++) {
      await settle();
      final s = container.read(eventSearchProvider(filters));
      if (!s.isLoading) return s;
    }
    return container.read(eventSearchProvider(filters));
  }

  group('the calls', () {
    test('home sends no point: the server places the caller', () async {
      api.on('GET', '/discover/home', homeBody());
      final repo = container.read(discoverRepositoryProvider);

      final home = (await repo.home()).right;

      final sent = api.sent('GET', '/discover/home').single;
      expect(sent.queryParameters, isEmpty);
      expect(home.where.label, 'Near Thiruvananthapuram');
      expect(home.where.source, WhereSource.ip);
      expect(home.near.single.name, 'Hack Night');
      expect(home.threads.single.id, 't-1');
    });

    test('events: the filters as the query', () async {
      api.on('GET', '/discover/events', eventsPage([eventCard(1)]));
      final repo = container.read(discoverRepositoryProvider);

      await repo.events(
        const EventFilters(when: EventWhen.today, price: EventPrice.free),
        const PageRequest.first(),
      );

      expect(api.sent('GET', '/discover/events').single.queryParameters, {
        'when': 'today',
        'price': 'free',
        'radius_km': 0,
        'offset': 0,
        'limit': discoverPageSize,
      });
    });

    test('calendar, clubs, threads and a topic go where they belong',
        () async {
      api
        ..on('GET', '/discover/calendar', {
          'month': '2026-11',
          'days': {'2026-11-02': 3, '2026-11-31': 1, '2026-11-09': 0},
        })
        ..on('GET', '/discover/clubs', clubsPage([clubCard(1)]))
        ..on('GET', '/discover/threads', threadsPage([threadOut('a')]))
        ..on('GET', '/interests/topics/development', developmentTopicBody);
      final repo = container.read(discoverRepositoryProvider);

      final month =
          (await repo.calendar(EventFilters.none, '2026-11')).right;
      final clubs = (await repo.clubs(
              const ClubFilters(sort: ClubSort.newest), const PageRequest.first()))
          .right;
      final threads = (await repo.threads(const PageRequest.first())).right;
      final topic = (await repo.topic('development')).right;

      expect(api.sent('GET', '/discover/calendar').single.queryParameters,
          {'month': '2026-11', 'radius_km': 0});
      // Not a day, and none on: left out.
      expect(month.days, {'2026-11-02': 3});
      expect(api.sent('GET', '/discover/clubs').single.queryParameters['sort'],
          'newest');
      expect(clubs.interests.first.name, 'Coding');
      expect(threads.items.single.id, 'a');
      expect(topic.upcomingEvents, 12);
      expect(topic.interests.map((i) => i.upcomingEvents), [4, 8]);
    });

    test('an unknown topic fails with 404', () async {
      final repo = container.read(discoverRepositoryProvider);
      final failure = (await repo.topic('nope')).left;
      expect(failure.code, '404');
    });
  });

  group('paging', () {
    test('the next page starts after the cursor, with no offset', () async {
      api
        ..on('GET', '/discover/events',
            eventsPage([eventCard(1), eventCard(2)], total: 5, nextCursor: 'c1'))
        ..on('GET', '/discover/events',
            eventsPage([eventCard(3), eventCard(4)], total: 5, nextCursor: 'c2'))
        ..on('GET', '/discover/events',
            eventsPage([eventCard(5)], total: 5, nextCursor: null));
      const filters = EventFilters(price: EventPrice.free);

      var state = await loaded(filters);
      expect(state.items.map((e) => e.id), [1, 2]);
      expect(state.next, const PageRequest.after('c1'));

      final notifier = container.read(eventSearchProvider(filters).notifier);
      await notifier.loadMore();
      await notifier.loadMore();
      state = container.read(eventSearchProvider(filters));

      final sent = api.sent('GET', '/discover/events');
      expect(sent, hasLength(3));
      expect(sent[1].queryParameters['after'], 'c1');
      expect(sent[2].queryParameters['after'], 'c2');
      for (final r in sent.skip(1)) {
        expect(r.queryParameters.containsKey('offset'), isFalse);
        expect(r.queryParameters['price'], 'free');
      }
      expect(state.items.map((e) => e.id), [1, 2, 3, 4, 5]);
      // A null cursor is the end: nothing more is asked.
      expect(state.hasMore, isFalse);
      await notifier.loadMore();
      expect(api.sent('GET', '/discover/events'), hasLength(3));
    });

    test('a repeated row is shown once', () async {
      api
        ..on('GET', '/discover/events',
            eventsPage([eventCard(1), eventCard(2)], nextCursor: 'c1'))
        ..on('GET', '/discover/events',
            eventsPage([eventCard(2), eventCard(3)], nextCursor: null));
      const filters = EventFilters(q: 'x');
      await loaded(filters);
      await container.read(eventSearchProvider(filters).notifier).loadMore();
      expect(container.read(eventSearchProvider(filters)).items.map((e) => e.id),
          [1, 2, 3]);
    });

    test('a failed later page keeps the list and offers a retry', () async {
      api.on('GET', '/discover/events',
          eventsPage([eventCard(1)], nextCursor: 'c1'));
      const filters = EventFilters(q: 'y');
      await loaded(filters);
      api.offline = true;
      final notifier = container.read(eventSearchProvider(filters).notifier);
      await notifier.loadMore();
      final state = container.read(eventSearchProvider(filters));
      expect(state.items, hasLength(1));
      expect(state.loadMoreError, isNotNull);
      expect(state.next, const PageRequest.after('c1'));
    });

    group('without cursors (an older server)', () {
      final full = [for (var i = 0; i < 20; i++) eventCard(i + 1)];

      test('pages by offset', () {
        final page = DiscoverPage<int>(
            items: List.filled(20, 0), total: 45, cursored: false);
        expect(nextPageAfter(page, 20), const PageRequest.offset(20));
        expect(nextPageAfter(page, 40), const PageRequest.offset(40));
        // Short of the total but read it all: the end.
        expect(nextPageAfter(page, 45), isNull);
      });

      test('never past 1,000: the server answers 422 there', () {
        final page = DiscoverPage<int>(
            items: List.filled(20, 0), total: 1000, capped: true);
        expect(nextPageAfter(page, 1000), const PageRequest.offset(1000));
        expect(nextPageAfter(page, 1020), isNull);
      });

      test('an empty page ends it, whatever the total said', () {
        const page = DiscoverPage<int>(items: [], total: 500);
        expect(nextPageAfter(page, 40), isNull);
      });

      test('the notifier sends the offset', () async {
        api
          ..on('GET', '/discover/events',
              eventsPage(full, total: 30, cursored: false))
          ..on('GET', '/discover/events',
              eventsPage(full.take(10).toList(), total: 30, cursored: false));
        const filters = EventFilters(q: 'z');
        await loaded(filters);
        await container.read(eventSearchProvider(filters).notifier).loadMore();
        final second = api.sent('GET', '/discover/events')[1];
        expect(second.queryParameters['offset'], 20);
        expect(second.queryParameters.containsKey('after'), isFalse);
      });
    });
  });

  group('saved first', () {
    test('the first page comes from the saved copy, then the network',
        () async {
      api.on('GET', '/discover/events', eventsPage([eventCard(1)]));
      const filters = EventFilters(price: EventPrice.paid);
      await loaded(filters);
      container.invalidate(eventSearchProvider(filters));

      // Now the server has moved on, but cannot be reached.
      api.offline = true;
      final first = await loaded(filters);
      // Drawn from the phone before the network has answered...
      expect(first.items.single.id, 1);
      for (var i = 0; i < 10; i++) {
        await settle();
      }
      // ...and kept, with no error, when it cannot be reached.
      final state = container.read(eventSearchProvider(filters));
      expect(state.items.single.id, 1);
      expect(state.error, isNull);
    });

    test('later pages are not saved', () async {
      api
        ..on('GET', '/discover/events',
            eventsPage([eventCard(1)], nextCursor: 'c1'))
        ..on('GET', '/discover/events', eventsPage([eventCard(2)]));
      const filters = EventFilters(q: 'saved');
      await loaded(filters);
      await container.read(eventSearchProvider(filters).notifier).loadMore();

      final keys = shared.values.keys;
      expect(keys.where((k) => k.contains('/discover/events')), hasLength(1));
      expect(keys.any((k) => k.contains('after=')), isFalse);
      final saved = await container
          .read(discoverRepositoryProvider)
          .savedEvents(filters);
      expect(saved!.page.items.single.id, 1);
    });

    test('offline with nothing saved: an error to retry', () async {
      api.offline = true;
      final state = await loaded(const EventFilters(q: 'never'));
      expect(state.items, isEmpty);
      expect(state.error, isNotNull);
    });

    test('home: saved copy first, then fresh', () async {
      api.on('GET', '/discover/home', homeBody());
      await container.read(discoverHomeProvider.future);
      container.invalidate(discoverHomeProvider);
      api.offline = true;

      final home = await container.read(discoverHomeProvider.future);
      expect(home.near.single.name, 'Hack Night');
    });
  });
}
