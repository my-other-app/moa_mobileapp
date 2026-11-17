import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../features/auth/auth_fakes.dart';

/// Answers every request with [status], noting what it carried.
class _Server implements HttpClientAdapter {
  _Server(this.status);

  final int status;
  final seen = <({Uri uri, Object? authorization})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add((
      uri: options.uri,
      authorization: options.headers['Authorization'],
    ));
    return ResponseBody.fromString('{}', status, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MemoryStorage storage;

  setUp(() {
    storage = MemoryStorage({'access_token': 'tok', 'refresh_token': 'ref'});
  });

  ({Dio dio, _Server server}) app({int status = 200}) {
    final server = _Server(status);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.myotherapp.in/api/v1'))
      ..httpClientAdapter = server;
    dio.interceptors.add(AuthInterceptor(storage, dio, onSessionEnded: (_) {}));
    return (dio: dio, server: server);
  }

  group('the session goes with', () {
    test('a request to an API path', () async {
      final t = app();
      await t.dio.get('/events/tickets/upcoming');
      expect(t.server.seen.single.authorization, 'Bearer tok');
    });

    test('a full address on the API\'s own host', () async {
      final t = app();
      await t.dio.get('https://api.myotherapp.in/api/v1/support/files/1');
      await t.dio.get('https://API.myotherapp.in:443/api/v1/x');
      expect(t.server.seen.map((s) => s.authorization),
          ['Bearer tok', 'Bearer tok']);
    });
  });

  group('the session never goes to', () {
    for (final url in [
      'https://moa-media.s3.amazonaws.com/avatars/1.jpg',
      'https://myotherapp.in/api/v1/x', // the website, not the API
      'https://api.myotherapp.in.example.org/x',
      'http://api.myotherapp.in/api/v1/x', // not over plain http
      'https://api.myotherapp.in:8443/api/v1/x',
    ]) {
      test(url, () async {
        final t = app();
        await t.dio.get(url);
        expect(t.server.seen.single.authorization, isNull);
      });
    }

    test('anywhere, from a Dio without a base address', () async {
      final server = _Server(200);
      final dio = Dio()..httpClientAdapter = server;
      dio.interceptors.add(AuthInterceptor(storage, dio));
      await dio.get('https://api.myotherapp.in/api/v1/x');
      expect(server.seen.single.authorization, isNull);
    });
  });

  test('another server\'s 401 is its own: no refresh, the session kept',
      () async {
    final t = app(status: 401);

    await expectLater(t.dio.get('https://elsewhere.example/file'),
        throwsA(isA<DioException>()));

    expect(t.server.seen.map((s) => s.uri.host), ['elsewhere.example']);
    expect(storage.values['refresh_token'], 'ref');
  });
}
