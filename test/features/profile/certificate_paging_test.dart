import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/features/profile/data/datasources/certificate_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// `/events/list?is_registered=true`, by offset, as the server pages it.
class _Server implements HttpClientAdapter {
  _Server(this.pages);

  /// offset -> (items, has a next page). A missing offset fails.
  final Map<int, (List<Map<String, dynamic>>, bool)> pages;
  final offsets = <int>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final offset = int.parse('${options.queryParameters['offset']}');
    offsets.add(offset);
    expect(options.queryParameters['limit'],
        CertificateRemoteDataSourceImpl.pageSize);
    final page = pages[offset];
    if (page == null) {
      throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
          error: const SocketException('offline'));
    }
    final (items, more) = page;
    return ResponseBody.fromString(
        jsonEncode({
          'limit': 100,
          'offset': offset,
          'items': items,
          'next': more ? '/events/list?offset=${offset + 100}' : null,
        }),
        200,
        headers: {
          'content-type': ['application/json'],
        });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _issued(int id) => {
      'id': id,
      'name': 'Talk $id',
      'event_datetime': '2026-0${1 + id % 9}-10T10:00:00Z',
      'ticket_id': 'MOA-T$id',
      'is_attended': true,
      'has_certificate': true,
    };

List<Map<String, dynamic>> _range(int from, int count) =>
    [for (var i = from; i < from + count; i++) _issued(i)];

void main() {
  late _Server server;

  CertificateRemoteDataSourceImpl source(
      Map<int, (List<Map<String, dynamic>>, bool)> pages) {
    server = _Server(pages);
    final cache =
        ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = server
      ..interceptors.add(ApiCacheInterceptor(cache));
    return CertificateRemoteDataSourceImpl(dio, cache: cache);
  }

  test('reads every page while the server says there is a next one', () async {
    final certificates = await source({
      0: (_range(0, 100), true),
      100: (_range(100, 100), true),
      200: (_range(200, 30), false),
    }).getMyCertificates();

    expect(certificates, hasLength(230));
    expect(server.offsets, [0, 100, 200]);
  });

  test('one page when there is no next', () async {
    final certificates =
        await source({0: (_range(0, 3), false)}).getMyCertificates();

    expect(certificates, hasLength(3));
    expect(server.offsets, [0]);
  });

  test('a later page that fails keeps what was read', () async {
    final certificates = await source({
      0: (_range(0, 100), true),
      // 100 fails: no signal.
    }).getMyCertificates();

    expect(certificates, hasLength(100));
  });

  test('the first page failing is an error, as before', () async {
    await expectLater(
        source({}).getMyCertificates(), throwsA(isA<DioException>()));
  });

  test('stops at the page cap, and on an empty page', () async {
    await source({
      for (var p = 0; p < 20; p++) p * 100: (_range(p * 100, 100), true),
    }).getMyCertificates();
    expect(server.offsets, hasLength(CertificateRemoteDataSourceImpl.maxPages));

    await source({
      0: (_range(0, 100), true),
      100: (const [], true),
    }).getMyCertificates();
    expect(server.offsets, [0, 100]);
  });

  test('a row repeated across pages is one certificate', () async {
    final certificates = await source({
      0: (_range(0, 100), true),
      100: (_range(99, 5), false),
    }).getMyCertificates();

    expect(certificates.map((c) => c.ticketId).toSet(), hasLength(104));
    expect(certificates, hasLength(104));
  });
}
