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
    return ResponseBody.fromString(status == 204 ? '' : '{"message":"x"}', status,
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
  test('DELETE /user/fcm-token with the token', () async {
    final s = _server(204);

    await deletePushTokenOnServer(s.dio, 'fcm-123');

    final request = s.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.uri.toString(), 'https://example.test/api/v1/user/fcm-token');
    expect(request.data, {'token': 'fcm-123'});
  });

  for (final status in [404, 405]) {
    test('an older server without the endpoint ($status) is ignored',
        () async {
      await expectLater(
          deletePushTokenOnServer(_server(status).dio, 'fcm-123'), completes);
    });
  }

  test('any other failure never stops a sign-out', () async {
    await expectLater(
        deletePushTokenOnServer(_server(500).dio, 'fcm-123'), completes);
    await expectLater(
        deletePushTokenOnServer(_server(401).dio, 'fcm-123'), completes);
  });
}
