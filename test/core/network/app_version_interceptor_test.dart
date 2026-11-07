// `X-App-Version: <version>+<build>` on every request the app makes,
// through the one Dio stack (`buildAppDio`) -- conditional-questions-
// contract.md §10. Nothing depends on it yet; it just has to be there.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/interceptors/app_version_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Answers 200 to everything and keeps what each request carried; fails
/// the first [dropFirst] connections as a dead network would.
class _Server implements HttpClientAdapter {
  final seen = <RequestOptions>[];
  int dropFirst = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    if (dropFirst > 0) {
      dropFirst--;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection reset',
        error: const SocketException('Connection reset'),
      );
    }
    return ResponseBody.fromString('{}', 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Server server;
  late Dio dio;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token-1'});
    PackageInfo.setMockInitialValues(
      appName: 'MyOtherApp',
      packageName: 'com.myotherapp.app',
      version: '1.1.0',
      buildNumber: '6',
      buildSignature: '',
    );
    AppVersion.reset();
    // As main() does at start-up.
    AppVersion.load();
    server = _Server();
    dio = buildAppDio(
      status: NetworkStatus(probe: () async => true),
      baseUrl: 'https://api.test/api/v1',
    )..httpClientAdapter = server;
  });

  String? sentVersion(RequestOptions options) =>
      options.headers[AppVersionInterceptor.header] as String?;

  test('every request says which build sent it', () async {
    await dio.get('/events/info/7');
    await dio.post('/events/registration/7/register', data: {'x': 1});
    await dio.put('/user/profile', data: {});
    await dio.delete('/clubs/follow/3');
    await dio.get('/events/discover', options: Options(extra: {'skipAuth': true}));

    expect(server.seen, hasLength(5));
    for (final request in server.seen) {
      expect(sentVersion(request), '1.1.0+6',
          reason: '${request.method} ${request.path}');
    }
    // Beside the session, not instead of it.
    expect(server.seen.first.headers['Authorization'], 'Bearer token-1');
  });

  test('a retried request carries it too', () async {
    server.dropFirst = 1;
    await dio.get('/events/info/7');
    expect(server.seen, hasLength(2));
    expect(server.seen.map(sentVersion), ['1.1.0+6', '1.1.0+6']);
  });

  group('reading the version', () {
    Future<List<String?>> send({int times = 1}) async {
      final own = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = server
        ..interceptors.add(AppVersionInterceptor());
      for (var i = 0; i < times; i++) {
        await own.get('/x');
      }
      return server.seen.map(sentVersion).toList();
    }

    setUp(AppVersion.reset);

    test('once, however many requests', () async {
      var reads = 0;
      AppVersion.load(() async {
        reads++;
        return '2.0.0+9';
      });
      AppVersion.load(() async => 'never asked');
      expect(await send(times: 3), ['2.0.0+9', '2.0.0+9', '2.0.0+9']);
      expect(reads, 1);
    });

    test('a request made while it is being read waits for it', () async {
      final read = Completer<String?>();
      AppVersion.load(() => read.future);
      final sent = send();
      await Future<void>.delayed(Duration.zero);
      expect(server.seen, isEmpty);
      read.complete('1.1.0+6');
      expect(await sent, ['1.1.0+6']);
    });

    test('unreadable, the request goes without it', () async {
      AppVersion.load(() async => throw Exception('no platform'));
      expect(await send(), [null]);
      expect(server.seen.single.headers.containsKey('X-App-Version'), isFalse);
    });

    test('never started (a test, say), the request goes as it always has',
        () async {
      expect(await send(), [null]);
    });
  });

  test('the value is <version>+<build>', () {
    expect(appVersionValue('1.1.0', '6'), '1.1.0+6');
    expect(appVersionValue(' 1.2.0 ', ' 12 '), '1.2.0+12');
    expect(appVersionValue('1.2.0', ''), '1.2.0');
    expect(appVersionValue('', '6'), isNull);
  });
}
