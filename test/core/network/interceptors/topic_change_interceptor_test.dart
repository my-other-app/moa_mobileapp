import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/topic_change_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

class _Answer implements HttpClientAdapter {
  _Answer(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(() => TopicChangeInterceptor.listener = null);

  test('the requests that change a person\'s topics', () {
    bool changes(String method, String path) =>
        TopicChangeInterceptor.changesTopics(method, path);

    expect(changes('POST', '/clubs/follow/12'), isTrue);
    expect(changes('POST', '/clubs/unfollow/12'), isTrue);
    expect(changes('POST', '/user/interests/select'), isTrue);
    expect(changes('PUT', '/notifications/mutes/clubs/12'), isTrue);
    expect(changes('DELETE', '/notifications/mutes/clubs/12'), isTrue);
    expect(changes('PATCH', '/notifications/settings'), isTrue);

    expect(changes('GET', '/notifications/mutes/clubs/12'), isFalse);
    expect(changes('GET', '/notifications/settings'), isFalse);
    expect(changes('POST', '/clubs/pin/12'), isFalse);
    expect(changes('POST', '/clubs/hide/12'), isFalse);
    expect(changes('POST', '/notifications/read-all'), isFalse);
  });

  test(
      'a follow that went through tells the listener; one that failed does not',
      () async {
    var told = 0;
    TopicChangeInterceptor.listener = () => told++;
    Dio dio(int status) =>
        Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
          ..httpClientAdapter = _Answer(status)
          ..interceptors.add(TopicChangeInterceptor());

    await dio(200).post<dynamic>('/clubs/follow/12');
    expect(told, 1);
    await dio(200).get<dynamic>('/clubs/list');
    expect(told, 1);
    await expectLater(
        dio(409).post<dynamic>('/clubs/follow/12'), throwsA(anything));
    expect(told, 1);
  });

  test('with no listener, nothing happens', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = _Answer(200)
      ..interceptors.add(TopicChangeInterceptor());

    await expectLater(dio.post<dynamic>('/clubs/follow/12'), completes);
  });
}
