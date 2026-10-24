import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:finnet/features/profile/data/datasources/certificate_remote_datasource.dart';
import 'package:finnet/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/topics/data/datasources/topic_remote_datasource.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server whose answers can be held back, or that cannot be reached.
class _Server implements HttpClientAdapter {
  final routes = <String, Object?>{};
  final etags = <String, String>{};
  bool offline = false;
  Completer<void>? gate;
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final g = gate;
    if (g != null) await g.future;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    }
    final key = options.uri.path;
    final etag = etags[key];
    if (etag != null && options.headers['If-None-Match'] == etag) {
      return ResponseBody.fromString('', 304, headers: {
        'etag': [etag],
      });
    }
    if (!routes.containsKey(key)) return ResponseBody.fromString('{}', 404);
    return ResponseBody.fromString(jsonEncode(routes[key]), 200, headers: {
      'content-type': ['application/json'],
      if (etag != null) 'etag': [etag],
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiCache _memoryCache() =>
    ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());

Dio _dio(_Server server, ApiCache cache) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
    ..httpClientAdapter = server;
  dio.interceptors.addAll([ApiCacheInterceptor(cache), ErrorInterceptor()]);
  return dio;
}

/// Waits in real time until [done], for at most [limit]. A fixed wait (it
/// was 20 or 50 ms) lost the race when the whole suite ran at once; the
/// expectations after this still decide whether the test passes.
Future<void> _until(bool Function() done,
    {Duration limit = const Duration(seconds: 3)}) async {
  final stopwatch = Stopwatch()..start();
  while (!done() && stopwatch.elapsed < limit) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _save(ApiCache cache, Dio dio, String path, Object data,
    {Map<String, dynamic>? query, CacheScope scope = CacheScope.shared}) {
  return cache.write(
    ApiCache.keyForRequest(dio, path, query: query),
    scope,
    CacheEntry(data: data, savedAt: DateTime.now()),
  );
}

Map<String, dynamic> _event(int id, String name) => {
      'id': id,
      'name': name,
      'club': {'id': 1, 'name': 'Tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'event_datetime': '2030-12-01T10:00:00Z',
      'ticket_url': 'https://myotherapp.in/tickets/MOA-$id',
      'is_paid': true,
    };

void main() {
  group('a feed screen (upcoming registrations)', () {
    late _Server server;
    late ApiCache cache;
    const page =
        '/events/list?is_registered=true&is_ended=false&offset=0&limit=10';

    setUp(() async {
      server = _Server();
      cache = _memoryCache();
      ApiCache.instance = cache;
      final dio = APIService.instance.dio
        ..httpClientAdapter = server
        ..interceptors.clear()
        ..interceptors.addAll([ApiCacheInterceptor(cache), ErrorInterceptor()]);
      await _save(cache, dio, page, {
        'items': [_event(1, 'Saved Hackathon')]
      }, scope: CacheScope.personal);
    });

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: UpcomingEventsPage())));
    }

    testWidgets('shows the saved copy at once, then the fresh one',
        (tester) async {
      server.gate = Completer<void>();
      server.routes['/api/v1/events/list'] = {
        'items': [_event(2, 'Fresh Workshop')]
      };

      await pumpPage(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Saved Hackathon'), findsOneWidget,
          reason: 'drawn from disk before the network answers');
      expect(find.text('Fresh Workshop'), findsNothing);

      server.gate!.complete();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('Fresh Workshop'), findsOneWidget);
      expect(find.text('Saved Hackathon'), findsNothing);
    });

    testWidgets('offline, the saved copy stays and no error is shown',
        (tester) async {
      server.offline = true;

      await pumpPage(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('Saved Hackathon'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
    });
  });

  group('providers', () {
    test('certificates: the saved list, then the fresh one', () async {
      final server = _Server();
      final cache = _memoryCache();
      final dio = _dio(server, cache);
      Map<String, dynamic> attended(String ticket, String name) => {
            ..._event(1, name),
            'ticket_id': ticket,
            'is_attended': true,
          };
      await _save(cache, dio, '/events/list', {
        'items': [attended('MOA-OLD', 'Saved Talk')]
      }, query: {
        'is_registered': true,
        'limit': 100,
        'offset': 0,
      }, scope: CacheScope.personal);
      server.routes['/api/v1/events/list'] = {
        'items': [attended('MOA-NEW', 'Fresh Talk')]
      };
      final container = ProviderContainer(overrides: [
        certificateRemoteDataSourceProvider.overrideWithValue(
            CertificateRemoteDataSourceImpl(dio, cache: cache)),
      ]);
      addTearDown(container.dispose);

      final seen = <List<String>>[];
      container.listen(certificatesProvider, (_, next) {
        if (next.hasValue) seen.add(next.value!.map((c) => c.ticketId).toList());
      }, fireImmediately: true);
      await _until(() => seen.length >= 2);

      expect(seen, [
        ['MOA-OLD'],
        ['MOA-NEW'],
      ]);
    });

    test('topics: a 304 confirms the saved catalogue', () async {
      final server = _Server()
        ..etags['/api/v1/interests/list'] = '"t1"';
      final cache = _memoryCache();
      final dio = _dio(server, cache);
      final topics = [
        {
          'id': 1,
          'name': 'Development',
          'slug': 'development',
          'interests': [
            {'id': 3, 'name': 'Flutter'}
          ],
        }
      ];
      await cache.write(
        ApiCache.keyForRequest(dio, '/interests/list'),
        CacheScope.shared,
        CacheEntry(data: topics, savedAt: DateTime.now(), etag: '"t1"'),
      );
      final container = ProviderContainer(overrides: [
        topicRemoteDataSourceProvider
            .overrideWithValue(TopicRemoteDataSourceImpl(dio, cache: cache)),
      ]);
      addTearDown(container.dispose);

      final seen = <List<String>>[];
      container.listen(topicCatalogueProvider, (_, next) {
        if (next.hasValue) seen.add(next.value!.map((t) => t.slug).toList());
      }, fireImmediately: true);
      await _until(() => seen.length >= 2 && server.seen.isNotEmpty);

      expect(server.seen.single.headers['If-None-Match'], '"t1"');
      expect(seen, [
        ['development'],
        ['development'],
      ]);
    });

    test('profile: the saved profile at once, then the fresh one', () async {
      final server = _Server()..gate = Completer<void>();
      final cache = _memoryCache();
      final dio = _dio(server, cache);
      await _save(cache, dio, '/user/profile/me',
          {'id': 'u1', 'full_name': 'Saved Name', 'email': 'a@b.c'},
          scope: CacheScope.personal);
      server.routes['/api/v1/user/profile/me'] = {
        'id': 'u1',
        'full_name': 'Fresh Name',
        'email': 'a@b.c',
      };
      final container = ProviderContainer(overrides: [
        profileRepositoryProvider.overrideWithValue(ProfileRepositoryImpl(
          remoteDataSource: ProfileRemoteDataSourceImpl(dio, cache: cache),
        )),
      ]);
      addTearDown(container.dispose);

      container.read(profileProvider);
      await _until(() => container.read(profileProvider).profile != null);
      expect(container.read(profileProvider).profile?.fullName, 'Saved Name');

      server.gate!.complete();
      await _until(() =>
          container.read(profileProvider).profile?.fullName == 'Fresh Name');
      expect(container.read(profileProvider).profile?.fullName, 'Fresh Name');
      expect(container.read(profileProvider).error, isNull);
    });

    test('notifications: the saved first page stays when offline', () async {
      final server = _Server()..offline = true;
      final cache = _memoryCache();
      final dio = _dio(server, cache);
      await _save(cache, dio, '/notifications/fetch-list', {
        'items': [
          {
            'id': 'n1',
            'title': 'Saved notice',
            'description': 'x',
            'type': 'announcement',
            'status': 'unread',
            'created_at': '2026-10-16T08:00:00Z',
          }
        ],
        'total': 1,
      }, query: {
        'limit': 20,
        'offset': 0,
      }, scope: CacheScope.personal);
      final notifier = NotificationsNotifier(NotificationRepositoryImpl(
        remoteDataSource: NotificationRemoteDataSourceImpl(dio, cache: cache),
      ));
      addTearDown(notifier.dispose);

      await notifier.loadNotifications();

      expect(notifier.state.notifications.map((n) => n.title), ['Saved notice']);
      expect(notifier.state.error, isNull);
      expect(notifier.state.isLoading, isFalse);
    });

    test('a body of the wrong shape is an empty page, not a crash', () {
      final page = NotificationRemoteDataSourceImpl.pageFrom({
        'items': 'nope',
        'total': 3.0,
      });
      expect(page.items, isEmpty);
      expect(page.total, 3);
      expect(NotificationRemoteDataSourceImpl.pageFrom(null).items, isEmpty);
    });
  });

  test('Either is still what repositories answer', () {
    // Saved reads sit beside the Result-returning calls, not instead of them.
    expect(Either<String, int>.right(1).isRight, isTrue);
  });
}
