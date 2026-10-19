// Offline, through the app's own Dio stack: the retry, the network status,
// the saved answers, the session and the error reading, exactly as
// `buildAppDio` puts them together -- over a server of the test's own that
// answers, refuses connections, never answers, or is down.
//
// The saved answers live in a temp-directory FileCacheStore (shared) and a
// memory store standing in for the Keychain (personal). A "cold start" is a
// new ApiCache and a new Dio over the same directory.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:finnet/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'https://api.test/api/v1';

/// A server that answers by path -- or refuses every connection
/// ([offline]), accepts and never answers ([hang]), or has a gateway in
/// front of it saying it is down ([down]).
class _Server implements HttpClientAdapter {
  final routes = <String, Object?>{};
  final etags = <String, String>{};
  bool offline = false;
  bool hang = false;
  int? down;
  final seen = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add('${options.method} ${options.uri.path}');
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
        error: const SocketException('Failed host lookup'),
      );
    }
    if (hang) {
      // What Dio reports when the connection opened and nothing came back
      // before the receive timeout.
      throw DioException.receiveTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 30),
      );
    }
    final gateway = down;
    if (gateway != null) {
      return ResponseBody.fromString('<html>Bad Gateway</html>', gateway,
          headers: {
            'content-type': ['text/html'],
          });
    }
    final path = options.uri.path;
    final etag = etags[path];
    if (etag != null && options.headers['If-None-Match'] == etag) {
      return ResponseBody.fromString('', 304, headers: {
        'etag': [etag],
      });
    }
    if (!routes.containsKey(path)) {
      return ResponseBody.fromString('{"message":"Not found"}', 404, headers: {
        'content-type': ['application/json'],
      });
    }
    final body = routes[path];
    if (body is int) {
      return ResponseBody.fromString('{"message":"no"}', body, headers: {
        'content-type': ['application/json'],
      });
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      'content-type': ['application/json'],
      if (etag != null) 'etag': [etag],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// The app's stack over [server], with its own network status (whose probe
/// never succeeds) and cache.
({Dio dio, NetworkStatus status}) _stack(_Server server, ApiCache cache) {
  ApiCache.instance = cache;
  final status = NetworkStatus(probe: () async => false);
  final dio = buildAppDio(status: status, baseUrl: _base)
    ..httpClientAdapter = server;
  return (dio: dio, status: status);
}

Map<String, dynamic> _home(String city) => {
      'where': {'city': city},
      'near': const [],
      'this_week': const [],
      'clubs': const [],
    };

const _profile = {
  'id': 42,
  'full_name': 'Aarav Menon',
  'email': 'aarav@example.com',
  'interests': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late _Server server;
  final statuses = <NetworkStatus>[];

  ApiCache newCache({MemoryCacheStore? personal}) => ApiCache(
        shared: FileCacheStore(root: () async => dir),
        personal: personal ?? MemoryCacheStore(),
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('offline_stack');
    server = _Server();
  });

  tearDown(() async {
    for (final status in statuses) {
      status.reportOnline();
    }
    statuses.clear();
    ApiCache.instance = null;
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  ({Dio dio, NetworkStatus status}) stack(ApiCache cache) {
    final s = _stack(server, cache);
    statuses.add(s.status);
    return s;
  }

  group('DISCOVER through the real stack', () {
    test('saved online, answered from the saved copy offline, and after a '
        'cold start', () async {
      server.routes['/api/v1/discover/home'] = _home('Kochi');
      server.etags['/api/v1/discover/home'] = 'W/"a"';
      final first = stack(newCache());
      final online = DiscoverRemoteDataSourceImpl(first.dio);
      expect((await online.home()).where.city, 'Kochi');

      // Revalidated by its ETag: a 304 keeps the copy.
      expect((await online.home()).where.city, 'Kochi');
      expect(server.seen.where((s) => s.endsWith('/discover/home')).length, 2);

      // Offline: the saved copy is the answer, and the app knows.
      server.offline = true;
      expect((await online.home()).where.city, 'Kochi');
      expect(first.status.isOffline, isTrue);

      // A cold start offline: a new cache and a new Dio over the same
      // directory find it, both as the saved copy and as the answer.
      final cold = stack(newCache());
      final coldSource = DiscoverRemoteDataSourceImpl(cold.dio);
      expect((await coldSource.savedHome())?.where.city, 'Kochi');
      expect((await coldSource.home()).where.city, 'Kochi');
    });

    test('a weak signal (no answer before the timeout) is answered from the '
        'saved copy, not an error', () async {
      server.routes['/api/v1/discover/home'] = _home('Kochi');
      final s = stack(newCache());
      final source = DiscoverRemoteDataSourceImpl(s.dio);
      await source.home();

      server.hang = true;
      final response = await s.dio.get<dynamic>('/discover/home',
          options: Options(extra: CachePolicy.shared.extra));
      expect(ApiCacheInterceptor.answerOf(response), CachedAnswer.offline);
      expect((await source.home()).where.city, 'Kochi');
    });

    for (final gateway in [502, 503, 504]) {
      test('a server that is down ($gateway) is answered from the saved copy',
          () async {
        server.routes['/api/v1/discover/home'] = _home('Kochi');
        final s = stack(newCache());
        final source = DiscoverRemoteDataSourceImpl(s.dio);
        await source.home();

        server.down = gateway;
        expect((await source.home()).where.city, 'Kochi');
      });
    }

    test('a 404 or a 500 is still the server speaking: not hidden', () async {
      server.routes['/api/v1/discover/home'] = _home('Kochi');
      final s = stack(newCache());
      final source = DiscoverRemoteDataSourceImpl(s.dio);
      await source.home();

      server.routes['/api/v1/discover/home'] = 500;
      await expectLater(source.home(), throwsA(isA<DioException>()));
    });
  });

  group('the profile, signed in', () {
    test('survives a cold start after many event pages: kept answers are '
        'never pruned for room', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'access_token': 'a', 'refresh_token': 'r'});
      final personal = MemoryCacheStore();
      server.routes['/api/v1/user/profile/me'] = _profile;
      final s = stack(newCache(personal: personal));
      final profiles = ProfileRemoteDataSourceImpl(s.dio);
      await profiles.getMyProfile();

      // Then the person looks at 45 events: each page is saved encrypted
      // (it carries their registration).
      final api = APIService.over(s.dio);
      for (var i = 0; i < 45; i++) {
        server.routes['/api/v1/events/info/$i'] = {'id': i, 'name': 'E$i'};
        await api.request('/events/info/$i', DioMethod.get,
            cache: CachePolicy.personal);
      }

      // The next start prunes to 40 encrypted answers.
      final cold = newCache(personal: personal);
      await cold.prune();
      final coldStack = stack(cold);
      final saved =
          await ProfileRemoteDataSourceImpl(coldStack.dio).getSavedProfile();
      expect(saved?.fullName, 'Aarav Menon',
          reason: 'the oldest answer, but one every screen leans on');
      expect(personal.values.length, lessThanOrEqualTo(41));

      // And offline the profile request is answered from it.
      server.offline = true;
      final offline =
          await ProfileRemoteDataSourceImpl(coldStack.dio).getMyProfile();
      expect(offline.fullName, 'Aarav Menon');
    });

    test('a refresh that fails offline keeps the session and the saved '
        'answers', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'access_token': 'old', 'refresh_token': 'r'});
      final ended = <SessionEndReason>[];
      final sub = SessionEvents.revoked.listen(ended.add);
      addTearDown(sub.cancel);
      final personal = MemoryCacheStore();
      server.routes['/api/v1/user/profile/me'] = _profile;
      final s = stack(newCache(personal: personal));
      await ProfileRemoteDataSourceImpl(s.dio).getMyProfile();
      final savedBefore = Map.of(personal.values);

      // The access token has expired; the refresh cannot reach the server.
      server.routes['/api/v1/user/profile/me'] = 401;
      final realFetch = server.fetch;
      final refreshOffline = _Refusing(server, realFetch);
      s.dio.httpClientAdapter = refreshOffline;

      final profile = await ProfileRemoteDataSourceImpl(s.dio)
          .getMyProfile()
          .then((p) => p.fullName, onError: (Object e) => 'failed: $e');
      expect(profile, startsWith('failed'));

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'access_token'), 'old');
      expect(await storage.read(key: 'refresh_token'), 'r');
      await Future<void>.delayed(Duration.zero);
      expect(ended, isEmpty, reason: 'no "your session has ended"');
      expect(personal.values, savedBefore);
    });
  });

  group('back online', () {
    test('counts each return, once', () {
      final status = NetworkStatus(probe: () async => false);
      statuses.add(status);
      expect(status.backOnline.value, 0);
      status.reportOffline();
      status.reportOffline();
      status.reportOnline();
      status.reportOnline();
      expect(status.backOnline.value, 1);
      status.reportOffline();
      status.reportOnline();
      expect(status.backOnline.value, 2);
    });
  });
}

/// [server], except that the refresh cannot connect.
class _Refusing implements HttpClientAdapter {
  _Refusing(this.server, this.answer);

  final _Server server;
  final Future<ResponseBody> Function(
      RequestOptions, Stream<Uint8List>?, Future<void>?) answer;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    if (options.uri.path.endsWith('/auth/refresh')) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    }
    return answer(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
