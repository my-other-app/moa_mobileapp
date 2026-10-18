import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Answer implements HttpClientAdapter {
  _Answer(this.status);

  final int status;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString('{"success": true, "message": "ok"}', status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _Answer adapter}) _server(int status) {
  final adapter = _Answer(status);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..httpClientAdapter = adapter
    ..interceptors.add(ErrorInterceptor());
  return (dio: dio, adapter: adapter);
}

void main() {
  test('a device in all its topics registers its token with topics: 1',
      () async {
    final s = _server(200);

    await registerPushTokenOnServer(s.dio, 'fcm-123',
        platform: 'ios', topics: true);

    final request = s.adapter.requests.single;
    expect(request.method, 'POST');
    expect(
        request.uri.toString(), 'https://example.test/api/v1/user/fcm-token');
    expect(
        request.data, {'fcm_token': 'fcm-123', 'platform': 'ios', 'topics': 1});
  });

  test('a device not (yet) in them sends the body it always sent', () async {
    final s = _server(200);

    await registerPushTokenOnServer(s.dio, 'fcm-123',
        platform: 'android', topics: false);

    expect(s.adapter.requests.single.data,
        {'fcm_token': 'fcm-123', 'platform': 'android'});
  });

  test('a failure never escapes', () async {
    await expectLater(
        registerPushTokenOnServer(_server(500).dio, 'fcm-123',
            platform: 'ios', topics: true),
        completes);
    await expectLater(
        registerPushTokenOnServer(_server(401).dio, 'fcm-123',
            platform: 'ios', topics: false),
        completes);
  });
}
