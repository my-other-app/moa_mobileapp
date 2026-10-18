import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _Answer implements HttpClientAdapter {
  _Answer(this.body);

  final String body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('cursorFromNext', () {
    test('the cursor in a next link', () {
      expect(
          cursorFromNext(
              '/api/v1/notifications/fetch-list?limit=20&offset=20&cursor=MjAyNi0xMC0xOA'),
          'MjAyNi0xMC0xOA');
    });

    test('none from a server that pages by offset, or on the last page', () {
      expect(
          cursorFromNext('/api/v1/notifications/fetch-list?limit=20&offset=20'),
          isNull);
      expect(cursorFromNext(null), isNull);
      expect(cursorFromNext(''), isNull);
    });
  });

  test('a page by cursor asks for it and hands on the next one', () async {
    final adapter = _Answer('{"limit": 20, "offset": 20, "total": null, '
        '"next": "/api/v1/notifications/fetch-list?limit=20&offset=40&cursor=NEXT", "items": []}');
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;

    final page = await NotificationRemoteDataSourceImpl(dio)
        .fetchList(limit: 20, offset: 20, cursor: 'THIS');

    expect(adapter.requests.single.queryParameters,
        {'limit': 20, 'offset': 20, 'cursor': 'THIS'});
    expect(page.nextCursor, 'NEXT');
  });

  test('without a cursor the request is what it always was', () async {
    final adapter = _Answer(
        '{"limit": 20, "offset": 0, "total": null, "next": null, "items": []}');
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;

    final page = await NotificationRemoteDataSourceImpl(dio)
        .fetchList(limit: 20, offset: 0);

    expect(adapter.requests.single.queryParameters, {'limit': 20, 'offset': 0});
    expect(page.nextCursor, isNull);
  });
}
