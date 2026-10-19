import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/auth_fakes.dart';

/// Answers by method and path. A handler that throws a connection error is
/// a request that never reached the server.
class _Server implements HttpClientAdapter {
  _Server(this.handlers);

  final Map<String, FutureOr<ResponseBody> Function(RequestOptions)> handlers;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final handler = handlers['${options.method} ${options.path}'];
    if (handler == null) return ResponseBody.fromString('{}', 404);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200, String? etag}) =>
    ResponseBody.fromString(body, status, headers: {
      'content-type': ['application/json'],
      if (etag != null) 'etag': [etag],
    });

Never _unreachable(RequestOptions options) =>
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Failed host lookup',
      error: const SocketException('Failed host lookup'),
    );

class _Clock {
  DateTime now = DateTime(2026, 10, 19, 10);
  DateTime call() => now;
}

({Dio dio, _Server server, ApiCache cache, MemoryCacheStore shared, MemoryStorage secure, _Clock clock})
    _setUp(Map<String, FutureOr<ResponseBody> Function(RequestOptions)> handlers) {
  final clock = _Clock();
  final shared = MemoryCacheStore(now: clock.call);
  final secure = MemoryStorage({'access_token': 'a', 'refresh_token': 'r'});
  final cache = ApiCache(
    shared: shared,
    personal: SecureCacheStore(secure),
    now: clock.call,
  );
  final server = _Server(handlers);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
    ..httpClientAdapter = server;
  dio.interceptors.addAll([
    RetryInterceptor(dio, sleep: (_) async {}),
    ApiCacheInterceptor(cache),
    ErrorInterceptor(),
  ]);
  return (dio: dio, server: server, cache: cache, shared: shared, secure: secure, clock: clock);
}

Options _cached([CachePolicy policy = CachePolicy.shared]) =>
    Options(extra: policy.extra);

void main() {
  group('ApiCacheInterceptor', () {
    test('saves an answer with its ETag, sends it back, and a 304 is the '
        'saved copy', () async {
      var version = 1;
      final t = _setUp({
        'GET /events/info/7': (o) => o.headers['If-None-Match'] == '"v$version"'
            ? ResponseBody.fromString('', 304, headers: {
                'etag': ['"v$version"'],
              })
            : _json('{"id":7,"name":"Hack $version"}', etag: '"v$version"'),
      });

      final first = await t.dio.get('/events/info/7', options: _cached());
      expect(first.data['name'], 'Hack 1');
      expect(ApiCacheInterceptor.answerOf(first), isNull);
      expect(t.server.requests.last.headers['If-None-Match'], isNull);

      t.clock.now = t.clock.now.add(const Duration(days: 3));
      final second = await t.dio.get('/events/info/7', options: _cached());
      expect(t.server.requests.last.headers['If-None-Match'], '"v1"');
      expect(second.statusCode, 200);
      expect(second.data, {'id': 7, 'name': 'Hack 1'});
      expect(ApiCacheInterceptor.answerOf(second), CachedAnswer.revalidated);

      // The 304 counts as confirmation: the copy's week starts again.
      final key = ApiCache.keyFor(Uri.parse('https://api.test/api/v1/events/info/7'));
      final saved = await t.cache.read(key, CacheScope.shared);
      expect(saved!.savedAt.isAtSameMomentAs(t.clock.now), isTrue);

      version = 2;
      final third = await t.dio.get('/events/info/7', options: _cached());
      expect(third.data['name'], 'Hack 2');
      expect(ApiCacheInterceptor.answerOf(third), isNull);
    });

    test('without ETags every answer is a full one and replaces the copy',
        () async {
      var name = 'A';
      final t = _setUp({
        'GET /clubs/info/3': (_) => _json('{"name":"$name"}'),
      });

      await t.dio.get('/clubs/info/3', options: _cached());
      name = 'B';
      final again = await t.dio.get('/clubs/info/3', options: _cached());

      expect(t.server.requests.last.headers['If-None-Match'], isNull);
      expect(again.data['name'], 'B');
      final key = ApiCache.keyFor(Uri.parse('https://api.test/api/v1/clubs/info/3'));
      expect((await t.cache.read(key, CacheScope.shared))!.data['name'], 'B');
    });

    test('offline, the saved copy is the answer, after one retry', () async {
      var online = true;
      final t = _setUp({
        'GET /interests/topics': (o) =>
            online ? _json('[{"id":1,"name":"Tech"}]') : _unreachable(o),
      });

      await t.dio.get('/interests/topics', options: _cached());
      online = false;
      final offline = await t.dio.get('/interests/topics', options: _cached());

      expect(offline.data, [
        {'id': 1, 'name': 'Tech'}
      ]);
      expect(ApiCacheInterceptor.answerOf(offline), CachedAnswer.offline);
      // The first try and the one retry.
      expect(t.server.requests, hasLength(3));
    });

    test('offline with nothing saved is the error it always was', () async {
      final t = _setUp({'GET /interests/topics': _unreachable});

      await expectLater(
        t.dio.get('/interests/topics', options: _cached()),
        throwsA(isA<DioException>()),
      );
    });

    test('a server error is not hidden behind the saved copy', () async {
      var fail = false;
      final t = _setUp({
        'GET /a': (_) => fail
            ? _json('{"message":"boom"}', status: 500)
            : _json('{"ok":true}'),
      });

      await t.dio.get('/a', options: _cached());
      fail = true;
      await expectLater(
          t.dio.get('/a', options: _cached()), throwsA(isA<DioException>()));
    });

    test('a copy older than a week is neither shown nor kept', () async {
      var online = true;
      final t = _setUp({
        'GET /a': (o) => online ? _json('{"ok":true}') : _unreachable(o),
      });

      await t.dio.get('/a', options: _cached());
      t.clock.now = t.clock.now.add(const Duration(days: 7, minutes: 1));
      online = false;

      await expectLater(
          t.dio.get('/a', options: _cached()), throwsA(isA<DioException>()));
      expect(t.shared.values, isEmpty);
    });

    test('nothing is saved without a policy', () async {
      final t = _setUp({'GET /a': (_) => _json('{"ok":true}')});

      await t.dio.get('/a');

      expect(t.shared.values, isEmpty);
    });

    test('never a POST, a PUT, a PATCH or a DELETE, even when asked',
        () async {
      final t = _setUp({
        for (final m in ['POST', 'PUT', 'PATCH', 'DELETE'])
          '$m /events/registration/7/register': (_) => _json('{"ok":true}'),
      });

      await t.dio.post('/events/registration/7/register', options: _cached());
      await t.dio.put('/events/registration/7/register', options: _cached());
      await t.dio.patch('/events/registration/7/register', options: _cached());
      await t.dio.delete('/events/registration/7/register', options: _cached());

      expect(t.shared.values, isEmpty);
    });

    test('never sign-in, payments, checkout or one-time tokens, even when '
        'asked', () async {
      const paths = [
        '/auth/me',
        '/payments/orders/9',
        '/events/7/checkout',
        '/user/email/verify',
        '/notifications/tokens',
        '/events/tickets/MOA-1/wallet.pkpass',
      ];
      final t = _setUp({
        for (final p in paths) 'GET $p': (_) => _json('{"secret":"x"}'),
      });

      for (final p in paths) {
        await t.dio.get(p, options: _cached(CachePolicy.personal));
      }

      expect(t.shared.values, isEmpty);
      expect(t.secure.values.keys.where((k) => k.startsWith('saved:')), isEmpty);
    });

    test('personal answers go to encrypted storage, beside the tokens but '
        'apart from them', () async {
      final t = _setUp({
        'GET /user/profile/me': (_) => _json('{"full_name":"Ana"}'),
      });

      await t.dio.get('/user/profile/me', options: _cached(CachePolicy.personal));

      expect(t.shared.values, isEmpty);
      expect(t.secure.values.keys,
          contains('saved:GET /api/v1/user/profile/me'));

      await t.cache.clear();
      expect(t.secure.values, {'access_token': 'a', 'refresh_token': 'r'});
    });

    test('an answer that lands after a sign-out cleared the cache is not '
        'saved', () async {
      final arrived = Completer<void>();
      final release = Completer<void>();
      final t = _setUp({
        'GET /events/list': (_) async {
          arrived.complete();
          await release.future;
          return _json('{"items":[]}');
        },
      });

      final pending = t.dio.get('/events/list', options: _cached());
      await arrived.future;
      await t.cache.clear();
      release.complete();
      await pending;

      expect(t.shared.values, isEmpty);
    });

    test('the query is part of the key, in any order', () {
      expect(
        ApiCache.keyFor(Uri.parse('https://x/api/v1/events/list?offset=0&limit=10')),
        ApiCache.keyFor(Uri.parse('https://x/api/v1/events/list?limit=10&offset=0')),
      );
      expect(
        ApiCache.keyFor(Uri.parse('https://x/events/list?offset=0')),
        isNot(ApiCache.keyFor(Uri.parse('https://x/events/list?offset=10'))),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://x/api/v1'));
      expect(
        ApiCache.keyForRequest(dio, '/events/list?offset=0', query: {'limit': 10}),
        'GET /api/v1/events/list?limit=10&offset=0',
      );
    });
  });

  group('ApiCache limits', () {
    test('an answer larger than an entry may be is not kept', () async {
      final store = MemoryCacheStore();
      final cache = ApiCache(
        shared: store,
        personal: MemoryCacheStore(),
        maxEntryBytes: 100,
      );

      await cache.write('k', CacheScope.shared,
          CacheEntry(data: 'x' * 200, savedAt: DateTime.now()));

      expect(store.values, isEmpty);
    });

    test('prune drops the expired, then the oldest over each cap', () async {
      final clock = _Clock();
      final shared = MemoryCacheStore(now: clock.call);
      final personal = MemoryCacheStore(now: clock.call);
      final cache = ApiCache(
        shared: shared,
        personal: personal,
        now: clock.call,
        maxSharedBytes: 250,
        maxPersonalEntries: 2,
      );
      Future<void> put(CacheStore store, String key) async {
        await store.write(key, 'y' * 100);
        clock.now = clock.now.add(const Duration(hours: 1));
      }

      await put(shared, 'ancient');
      clock.now = clock.now.add(const Duration(days: 8));
      await put(shared, 'old');
      await put(shared, 'mid');
      await put(shared, 'new');
      await put(personal, 'p1');
      await put(personal, 'p2');
      await put(personal, 'p3');

      await cache.prune();

      expect(shared.values.keys, unorderedEquals(['mid', 'new']));
      expect(personal.values.keys, unorderedEquals(['p2', 'p3']));
    });

    test('an unreadable copy is a miss, not a crash', () async {
      final store = MemoryCacheStore()..values['k'] = '{not json';
      final cache = ApiCache(shared: store, personal: MemoryCacheStore());

      expect(await cache.read('k', CacheScope.shared), isNull);
    });
  });

  group('FileCacheStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('api_cache_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('writes, reads, lists and clears', () async {
      final store = FileCacheStore(root: () async => Directory('${dir.path}/c'));

      await store.write('GET /a', '{"x":1}');
      await store.write('GET /b', '{"y":2}');

      expect(await store.read('GET /a'), '{"x":1}');
      expect(await store.read('GET /missing'), isNull);
      final listed = await store.list();
      expect(listed.map((i) => i.key), unorderedEquals(['GET /a', 'GET /b']));
      expect(listed.every((i) => i.bytes > 0), isTrue);

      await store.delete('GET /a');
      expect(await store.read('GET /a'), isNull);

      await store.clear();
      expect(await store.read('GET /b'), isNull);
    });

    test('a file holding another key reads as a miss', () async {
      final store = FileCacheStore(root: () async => dir);
      await store.write('GET /a', 'A');
      final file = File('${dir.path}/${FileCacheStore.fileNameFor('GET /a')}');
      await file.writeAsString('GET /other\nB');

      expect(await store.read('GET /a'), isNull);
    });
  });

  group('APIService.getSavedThenFresh', () {
    late ApiCache previous;

    setUp(() => previous = ApiCache.instance);
    tearDown(() => ApiCache.instance = previous);

    test('shows the saved copy at once, then the fresh answer', () async {
      var count = 1;
      final t = _setUp({
        'GET /events/for-you': (_) => _json('{"items":[$count]}'),
      });
      ApiCache.instance = t.cache;
      final api = APIService.over(t.dio);

      await t.dio.get('/events/for-you', options: _cached());
      count = 2;

      final seen = <String>[];
      await api.getSavedThenFresh('/events/for-you', onData: (data, {required fresh}) {
        seen.add('${data['items']} ${fresh ? 'fresh' : 'saved'}');
      });

      expect(seen, ['[1] saved', '[2] fresh']);
    });

    test('a 304 hands back the saved body as the fresh answer', () async {
      final t = _setUp({
        'GET /events/for-you': (o) => o.headers['If-None-Match'] == '"e1"'
            ? ResponseBody.fromString('', 304)
            : _json('{"items":[1]}', etag: '"e1"'),
      });
      ApiCache.instance = t.cache;
      final api = APIService.over(t.dio);
      await t.dio.get('/events/for-you', options: _cached());

      final seen = <String>[];
      await api.getSavedThenFresh('/events/for-you', onData: (data, {required fresh}) {
        seen.add('${data['items']} ${fresh ? 'fresh' : 'saved'}');
      });

      expect(seen, ['[1] saved', '[1] fresh']);
    });

    test('offline after the saved copy: the copy stays and nothing throws',
        () async {
      var online = true;
      final t = _setUp({
        'GET /events/for-you': (o) =>
            online ? _json('{"items":[1]}') : _unreachable(o),
      });
      ApiCache.instance = t.cache;
      final api = APIService.over(t.dio);
      await t.dio.get('/events/for-you', options: _cached());
      online = false;

      final seen = <bool>[];
      await api.getSavedThenFresh('/events/for-you',
          onData: (_, {required fresh}) => seen.add(fresh));

      expect(seen, [false]);
    });

    test('with nothing saved, a failure is thrown as before', () async {
      final t = _setUp({'GET /events/for-you': _unreachable});
      ApiCache.instance = t.cache;
      final api = APIService.over(t.dio);

      await expectLater(
        api.getSavedThenFresh('/events/for-you', onData: (_, {required fresh}) {}),
        throwsA(anything),
      );
    });
  });
}
