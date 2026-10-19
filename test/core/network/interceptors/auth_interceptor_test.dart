import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/interceptors/auth_interceptor.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';

import '../../../features/auth/auth_fakes.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

/// Fake HTTP adapter that answers by path, without touching the network —
/// lets the real Dio + AuthInterceptor pipeline run end to end in tests.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handlers);

  final Map<String, FutureOr<ResponseBody> Function(RequestOptions)> _handlers;

  static const _jsonHeaders = {
    'content-type': ['application/json'],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = _handlers[options.path];
    if (handler == null) {
      return ResponseBody.fromString(
        '{"message":"not found"}',
        404,
        headers: _jsonHeaders,
      );
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('AuthInterceptor', () {
    test('refreshes the token and retries the original request on 401', () async {
      final storage = MockSecureStorageService();
      when(() => storage.getAccessToken()).thenAnswer((_) async => 'old-token');
      when(() => storage.getRefreshToken()).thenAnswer((_) async => 'refresh-token');
      when(() => storage.saveAccessToken(any())).thenAnswer((_) async {});
      when(() => storage.saveRefreshToken(any())).thenAnswer((_) async {});

      var protectedCallCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _FakeHttpClientAdapter({
        '/protected': (options) {
          protectedCallCount++;
          if (protectedCallCount == 1) {
            return ResponseBody.fromString(
              '{"message":"unauthorized"}',
              401,
              headers: _FakeHttpClientAdapter._jsonHeaders,
            );
          }
          return ResponseBody.fromString(
            '{"ok":true}',
            200,
            headers: _FakeHttpClientAdapter._jsonHeaders,
          );
        },
        '/auth/refresh': (options) => ResponseBody.fromString(
              '{"access_token":"new-token","refresh_token":"new-refresh-token"}',
              200,
              headers: _FakeHttpClientAdapter._jsonHeaders,
            ),
      });
      dio.interceptors.add(AuthInterceptor(storage, dio));

      final response = await dio.get('/protected');

      expect(response.statusCode, 200);
      expect(response.data['ok'], true);
      expect(protectedCallCount, 2, reason: 'the original request should be retried exactly once');
      verify(() => storage.saveAccessToken('new-token')).called(1);
      verify(() => storage.saveRefreshToken('new-refresh-token')).called(1);
    });

    test('logs out and propagates the error when there is no refresh token', () async {
      final storage = MockSecureStorageService();
      when(() => storage.getAccessToken()).thenAnswer((_) async => 'old-token');
      when(() => storage.getRefreshToken()).thenAnswer((_) async => null);
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _FakeHttpClientAdapter({
        '/protected': (options) => ResponseBody.fromString(
              '{"message":"unauthorized"}',
              401,
              headers: _FakeHttpClientAdapter._jsonHeaders,
            ),
      });
      dio.interceptors.add(AuthInterceptor(storage, dio));

      await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      verify(() => storage.delete(key: 'access_token')).called(1);
      verify(() => storage.delete(key: 'refresh_token')).called(1);
    });
  });

  group('when the session ends', () {
    ResponseBody json(String body, int status) => ResponseBody.fromString(
          body,
          status,
          headers: _FakeHttpClientAdapter._jsonHeaders,
        );

    /// The app's Dio, reduced: the auth interceptor ahead of the error
    /// interceptor, as buildAppDio() orders them.
    ({Dio dio, MemoryStorage storage, List<SessionEndReason> ended, Map<String, int> calls})
        setUp(
      Map<String, FutureOr<ResponseBody> Function(RequestOptions)> handlers, {
      Map<String, String>? stored,
    }) {
      final storage = MemoryStorage(stored ??
          {'access_token': 'old-token', 'refresh_token': 'refresh-token'});
      final ended = <SessionEndReason>[];
      final calls = <String, int>{};
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _FakeHttpClientAdapter({
        for (final entry in handlers.entries)
          entry.key: (options) {
            calls[entry.key] = (calls[entry.key] ?? 0) + 1;
            return entry.value(options);
          },
      });
      dio.interceptors.addAll([
        AuthInterceptor(storage, dio, onSessionEnded: ended.add),
        ErrorInterceptor(),
      ]);
      return (dio: dio, storage: storage, ended: ended, calls: calls);
    }

    test('a refused refresh deletes the tokens and says the session ended',
        () async {
      final t = setUp({
        '/protected': (_) => json('{"message":"Token has expired","error_code":"TOKEN_EXPIRED"}', 401),
        '/auth/refresh': (_) => json('{"message":"This session was signed out"}', 401),
      });

      final error = await t.dio.get('/protected').then<Object?>((_) => null,
          onError: (Object e) => e);

      expect(t.ended, [SessionEndReason.expired]);
      expect(t.storage.values, isEmpty);
      // The screen behind is about to give way to sign-in; what it shows
      // meanwhile is plain words, not "Could not validate credentials".
      final api = (error as DioException).error as ApiException;
      expect(api.type, ApiExceptionType.unauthorized);
      expect(api.userMessage, ApiException.sessionEndedMessage);
      expect(api.errorCode, 'TOKEN_EXPIRED');
    });

    test('someone never signed in is not told their session ended', () async {
      final t = setUp(
        {'/protected': (_) => json('{"message":"Could not validate credentials"}', 401)},
        stored: {},
      );

      await expectLater(t.dio.get('/protected'), throwsA(isA<DioException>()));
      expect(t.ended, isEmpty);
    });

    test('a refresh that fails for want of a network keeps the session',
        () async {
      final t = setUp({
        '/protected': (_) => json('{"message":"Token has expired"}', 401),
        '/auth/refresh': (_) => json('{"message":"Internal Server Error"}', 500),
      });

      await expectLater(t.dio.get('/protected'), throwsA(isA<DioException>()));
      expect(t.ended, isEmpty);
      expect(t.storage.values['refresh_token'], 'refresh-token');
    });

    test('a 401 that a fresh token does not cure is refreshed once, not forever',
        () async {
      // The volunteer check-in answers 401 for "not a volunteer here". It
      // used to refresh and retry until the rate limiter stopped it.
      final t = setUp({
        '/protected': (_) => json('{"message":"User is not a volunteer for this event"}', 401),
        '/auth/refresh': (_) => json('{"access_token":"new","refresh_token":"new-r"}', 200),
      });

      final error = await t.dio.get('/protected').then<Object?>((_) => null,
          onError: (Object e) => e);

      expect(t.calls['/protected'], 2);
      expect(t.calls['/auth/refresh'], 1);
      expect(t.ended, isEmpty);
      final api = (error as DioException).error as ApiException;
      expect(api.serverMessage, 'User is not a volunteer for this event');
      expect(api.userMessage, 'User is not a volunteer for this event');
    });

    /// A refresh slow enough that every request's 401 arrives while it runs.
    Future<ResponseBody> slowly(ResponseBody body) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return body;
    }

    test('requests that 401 together share one refresh, and all complete',
        () async {
      final t = setUp({
        '/a': (options) => options.headers['Authorization'] == 'Bearer new'
            ? json('{"ok":true}', 200)
            : json('{"message":"Token has expired"}', 401),
        '/auth/refresh': (_) =>
            slowly(json('{"access_token":"new","refresh_token":"new-r"}', 200)),
      });
      final results = await Future.wait([
        t.dio.get('/a'),
        t.dio.get('/a'),
        t.dio.get('/a'),
      ]);

      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(t.calls['/auth/refresh'], 1);
    });

    test('a refused refresh fails every waiting request, none hangs',
        () async {
      final t = setUp({
        '/a': (_) => json('{"message":"Token has expired"}', 401),
        '/auth/refresh': (_) =>
            slowly(json('{"message":"Token has expired"}', 401)),
      });

      final outcomes = await Future.wait([
        for (var i = 0; i < 3; i++)
          t.dio.get('/a').then((_) => 'ok', onError: (_) => 'failed'),
      ]).timeout(const Duration(seconds: 5));

      expect(outcomes, ['failed', 'failed', 'failed']);
      expect(t.calls['/auth/refresh'], 1);
    });

    test('a refresh that lands after sign-out does not bring the session back',
        () async {
      // Sign-out stops waiting on the server after a few seconds and clears
      // the tokens; a refresh still in flight must not save new ones.
      late MemoryStorage storage;
      final t = setUp({
        '/protected': (_) => json('{"message":"Token has expired"}', 401),
        '/auth/refresh': (_) {
          storage.values.clear();
          return json('{"access_token":"new","refresh_token":"new-r"}', 200);
        },
      });
      storage = t.storage;

      await expectLater(t.dio.get('/protected'), throwsA(isA<DioException>()));
      expect(t.storage.values, isEmpty);
      expect(t.calls['/protected'], 1);
    });

    test('a suspended account ends the session', () async {
      final t = setUp({
        '/protected': (_) => json(
            '{"message":"This account has been suspended","error_code":"ACCOUNT_SUSPENDED"}',
            403),
      });

      await expectLater(t.dio.get('/protected'), throwsA(isA<DioException>()));
      expect(t.ended, [SessionEndReason.suspended]);
      expect(t.storage.values, isEmpty);
    });

    test("a sign-in call's 401 is a wrong password, not a refresh", () async {
      final t = setUp({
        '/auth/token': (_) => json('{"message":"Incorrect username or password"}', 401),
      });

      await expectLater(
        t.dio.post('/auth/token', options: Options(extra: {'skipAuth': true})),
        throwsA(isA<DioException>()),
      );
      expect(t.calls['/auth/refresh'], isNull);
      expect(t.ended, isEmpty);
      expect(t.storage.values, isNotEmpty);
    });
  });

  // The server issues a new refresh token on every refresh. The one sent
  // stays good until the new one is first used; anything older then ends the
  // session with 401 SESSION_REUSED.
  group('refresh rotation', () {
    ResponseBody json(String body, int status) => ResponseBody.fromString(
          body,
          status,
          headers: _FakeHttpClientAdapter._jsonHeaders,
        );

    ({Dio dio, MemoryStorage storage, List<SessionEndReason> ended, Map<String, int> calls})
        setUp(Map<String, FutureOr<ResponseBody> Function(RequestOptions)> handlers) {
      final storage =
          MemoryStorage({'access_token': 'a0', 'refresh_token': 'r0'});
      final ended = <SessionEndReason>[];
      final calls = <String, int>{};
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _FakeHttpClientAdapter({
        for (final entry in handlers.entries)
          entry.key: (options) {
            calls[entry.key] = (calls[entry.key] ?? 0) + 1;
            return entry.value(options);
          },
      });
      dio.interceptors.addAll([
        AuthInterceptor(storage, dio, onSessionEnded: ended.add),
        ErrorInterceptor(),
      ]);
      return (dio: dio, storage: storage, ended: ended, calls: calls);
    }

    String sentToken(RequestOptions options) => (options.data as FormData)
        .fields
        .singleWhere((field) => field.key == 'token')
        .value;

    const expired =
        '{"message":"Token has expired","error_code":"TOKEN_EXPIRED"}';

    test('every refresh keeps both new tokens, and the next sends the new one',
        () async {
      final live = <String>{};
      final presented = <String>[];
      var generation = 0;
      final t = setUp({
        '/a': (options) => live.contains(options.headers['Authorization'])
            ? json('{"ok":true}', 200)
            : json(expired, 401),
        '/auth/refresh': (options) {
          presented.add(sentToken(options));
          generation++;
          live.add('Bearer a$generation');
          return json(
              '{"access_token":"a$generation","refresh_token":"r$generation"}',
              200);
        },
      });

      expect((await t.dio.get('/a')).statusCode, 200);
      expect(t.storage.values,
          {'access_token': 'a1', 'refresh_token': 'r1'});

      live.clear(); // a1 expires
      expect((await t.dio.get('/a')).statusCode, 200);

      expect(presented, ['r0', 'r1']);
      expect(t.storage.values,
          {'access_token': 'a2', 'refresh_token': 'r2'});
      expect(t.ended, isEmpty);
    });

    test('a 401 that lands after the refresh finished is retried with the new '
        'token, not refreshed again', () async {
      // Two requests leave with a0. The quick one's 401 sets off the
      // refresh; the slow one's arrives after it has finished. Refreshing
      // again for it would spend r1 at once -- and, against a server that
      // has already seen r1 used, r0 would end the session.
      final presented = <String>[];
      final t = setUp({
        '/quick': (options) => options.headers['Authorization'] == 'Bearer a1'
            ? json('{"ok":true}', 200)
            : json(expired, 401),
        '/slow': (options) async {
          if (options.headers['Authorization'] == 'Bearer a1') {
            return json('{"ok":true}', 200);
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return json(expired, 401);
        },
        '/auth/refresh': (options) {
          presented.add(sentToken(options));
          return json('{"access_token":"a1","refresh_token":"r1"}', 200);
        },
      });

      final results = await Future.wait([t.dio.get('/quick'), t.dio.get('/slow')]);

      expect(results.map((r) => r.statusCode), [200, 200]);
      expect(presented, ['r0']);
      expect(t.calls['/slow'], 2);
      expect(t.storage.values, {'access_token': 'a1', 'refresh_token': 'r1'});
    });

    test('a request retried with the new token and refused again is reported, '
        'not refreshed', () async {
      final t = setUp({
        '/quick': (options) => options.headers['Authorization'] == 'Bearer a1'
            ? json('{"ok":true}', 200)
            : json(expired, 401),
        '/slow': (options) async {
          if (options.headers['Authorization'] != 'Bearer a1') {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          return json(
              '{"message":"User is not a volunteer for this event"}', 401);
        },
        '/auth/refresh': (_) =>
            json('{"access_token":"a1","refresh_token":"r1"}', 200),
      });

      final outcomes = await Future.wait([
        t.dio.get('/quick').then((_) => 'ok', onError: (_) => 'failed'),
        t.dio.get('/slow').then((_) => 'ok', onError: (Object e) {
          final api = (e as DioException).error as ApiException;
          return api.serverMessage;
        }),
      ]).timeout(const Duration(seconds: 5));

      expect(outcomes, ['ok', 'User is not a volunteer for this event']);
      expect(t.calls['/slow'], 2);
      expect(t.calls['/auth/refresh'], 1);
      expect(t.ended, isEmpty);
    });

    test('five requests that 401 together cause exactly one refresh, and '
        'every one is retried with the new token', () async {
      final presented = <String>[];
      final retriedWith = <Object?>[];
      final t = setUp({
        for (var i = 0; i < 5; i++)
          '/r$i': (options) async {
            if (options.headers['Authorization'] == 'Bearer a1') {
              retriedWith.add(options.headers['Authorization']);
              return json('{"n":$i}', 200);
            }
            // Staggered, so some 401s land before the refresh starts, some
            // while it runs, and some after it has finished.
            await Future<void>.delayed(Duration(milliseconds: 15 * i));
            return json(expired, 401);
          },
        '/auth/refresh': (options) async {
          presented.add(sentToken(options));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return json('{"access_token":"a1","refresh_token":"r1"}', 200);
        },
      });

      final results = await Future.wait([
        for (var i = 0; i < 5; i++) t.dio.get('/r$i'),
      ]).timeout(const Duration(seconds: 5));

      expect(results.map((r) => r.data['n']), [0, 1, 2, 3, 4]);
      expect(t.calls['/auth/refresh'], 1);
      expect(presented, ['r0']);
      expect(retriedWith, List.filled(5, 'Bearer a1'));
      expect(t.storage.values, {'access_token': 'a1', 'refresh_token': 'r1'});
      expect(t.ended, isEmpty);
    });

    test('a 401 whose storage read outlasts a whole refresh is retried, not '
        'refreshed a second time', () async {
      // The slow request's 401 arrives first and reads the stored token;
      // that read is slow. Meanwhile another request's 401 starts and
      // finishes the refresh. The slow read then returns the token from
      // before the refresh -- the same one the request carried -- which
      // used to look like "nothing has refreshed yet" and spent r1 on a
      // second refresh.
      final storage = _SlowReadStorage(
          {'access_token': 'a0', 'refresh_token': 'r0'});
      final calls = <String, int>{};
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      ResponseBody count(String path, ResponseBody body) {
        calls[path] = (calls[path] ?? 0) + 1;
        return body;
      }

      dio.httpClientAdapter = _FakeHttpClientAdapter({
        '/slow': (options) {
          if (options.headers['Authorization'] == 'Bearer a1') {
            return count('/slow', json('{"ok":true}', 200));
          }
          // The next storage read is this 401's, in the interceptor.
          storage.slowNextRead = const Duration(milliseconds: 120);
          return count('/slow', json(expired, 401));
        },
        '/quick': (options) async {
          if (options.headers['Authorization'] == 'Bearer a1') {
            return count('/quick', json('{"ok":true}', 200));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return count('/quick', json(expired, 401));
        },
        '/auth/refresh': (_) => count(
            '/auth/refresh', json('{"access_token":"a1","refresh_token":"r1"}', 200)),
      });
      dio.interceptors.addAll([
        AuthInterceptor(storage, dio, onSessionEnded: (_) {}),
        ErrorInterceptor(),
      ]);

      final results = await Future.wait([dio.get('/slow'), dio.get('/quick')])
          .timeout(const Duration(seconds: 5));

      expect(results.map((r) => r.statusCode), [200, 200]);
      expect(calls['/auth/refresh'], 1);
      expect(calls['/slow'], 2);
      expect(storage.values, {'access_token': 'a1', 'refresh_token': 'r1'});
    });

    test('SESSION_REUSED signs out once, for every waiting request, and '
        'nothing loops', () async {
      final t = setUp({
        '/a': (_) => json(expired, 401),
        '/auth/refresh': (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return json(
              '{"message":"This session was ended because its sign-in was '
              'used from two places. Sign in again.",'
              '"error_code":"SESSION_REUSED"}',
              401);
        },
      });

      final errors = await Future.wait([
        for (var i = 0; i < 3; i++)
          t.dio.get('/a').then<Object?>((_) => null, onError: (Object e) => e),
      ]).timeout(const Duration(seconds: 5));

      expect(t.ended, [SessionEndReason.expired]);
      expect(t.calls['/auth/refresh'], 1);
      expect(t.storage.values, isEmpty);
      for (final error in errors) {
        final api = (error as DioException).error as ApiException;
        expect(api.userMessage, ApiException.sessionEndedMessage);
      }

      // What the screen behind asks for next finds no session: no refresh,
      // and nothing said a second time.
      await expectLater(t.dio.get('/a'), throwsA(isA<DioException>()));
      expect(t.calls['/auth/refresh'], 1);
      expect(t.ended, [SessionEndReason.expired]);
    });
  });
}

/// [MemoryStorage] whose next access-token read can be made slow. The value
/// is taken when the read starts, as a real store's would be.
class _SlowReadStorage extends MemoryStorage {
  _SlowReadStorage(super.initial);

  Duration? slowNextRead;

  @override
  Future<String?> getAccessToken() async {
    final value = values['access_token'];
    final delay = slowNextRead;
    slowNextRead = null;
    if (delay != null) await Future<void>.delayed(delay);
    return value;
  }
}
