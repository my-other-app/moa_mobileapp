import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finnet/core/network/interceptors/auth_interceptor.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

/// Fake HTTP adapter that answers by path, without touching the network —
/// lets the real Dio + AuthInterceptor pipeline run end to end in tests.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handlers);

  final Map<String, ResponseBody Function(RequestOptions)> _handlers;

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
}
