// The volunteer's events with no signal at the venue, through the app's own
// Dio stack (`buildAppDio`): the list is the only way to the door scanner
// (Settings shows "Volunteer Check-in" only when it has events), so a copy
// read online must still open the scanner after the app restarts offline.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/volunteer/data/datasources/volunteer_remote_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'https://api.test/api/v1';
const _path = '/api/v1/events/volunteer/my-events';

/// Answers the list, or refuses every connection ([offline]), or accepts
/// and never answers ([hang]).
class _Server implements HttpClientAdapter {
  Object? body;
  bool offline = false;
  bool hang = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
        error: const SocketException('Failed host lookup'),
      );
    }
    if (hang) {
      throw DioException.receiveTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 30),
      );
    }
    if (options.uri.path != _path) {
      return ResponseBody.fromString('{"message":"Not found"}', 404, headers: {
        'content-type': ['application/json'],
      });
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _devfest = {
  'id': 1,
  'slug': 'devfest',
  'name': 'DevFest',
  'event_datetime': '2026-11-28T03:00:00Z',
  'has_fee': false,
  'reg_fee': 0,
  'club': {'name': 'GDG'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late _Server server;
  late MemoryCacheStore personal;
  final statuses = <NetworkStatus>[];

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('volunteer_events_offline');
    server = _Server()..body = [_devfest];
    // The Keychain's stand-in: kept across a "restart" like the real one.
    personal = MemoryCacheStore();
  });

  tearDown(() async {
    for (final status in statuses) {
      status.reportOnline();
    }
    statuses.clear();
    ApiCache.instance = null;
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// The app, started afresh over the same saved answers.
  VolunteerRemoteDataSource start() {
    ApiCache.instance = ApiCache(
      shared: FileCacheStore(root: () async => dir),
      personal: personal,
    );
    final status = NetworkStatus(probe: () async => false);
    statuses.add(status);
    final dio = buildAppDio(status: status, baseUrl: _base)
      ..httpClientAdapter = server;
    return VolunteerRemoteDataSourceImpl(dio);
  }

  test(
      'read once online, the list still opens after a restart with no '
      'signal', () async {
    expect((await start().myEvents()).single.name, 'DevFest');

    server.offline = true;
    final events = await start().myEvents();
    expect(events.single.id, 1);
  });

  test('a weak signal (no answer before the timeout) is the saved list too',
      () async {
    await start().myEvents();

    server.hang = true;
    expect((await start().myEvents()).single.name, 'DevFest');
  });

  test('never read since signing in: no signal is still an error', () async {
    server.offline = true;
    await expectLater(start().myEvents(), throwsA(isA<DioException>()));
  });

  test('the server answering is always the fresh list', () async {
    await start().myEvents();
    server.body = const [];
    expect(await start().myEvents(), isEmpty);
  });
}
