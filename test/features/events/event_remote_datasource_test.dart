import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/features/events/data/datasources/event_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the request Dio was about to make and answers with a canned body.
///
/// The request is the thing under test. All eight of this data source's calls
/// addressed routes the server does not have, and a test that only checked
/// the parsed output would have passed throughout.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object body = const <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  RequestOptions get only => requests.single;
}

void main() {
  late _RecordingAdapter adapter;
  late EventRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    dataSource = EventRemoteDataSourceImpl(dio);
  });

  group('paths match the server', () {
    test('the event list is /events/list', () async {
      adapter.body = {'items': []};

      await dataSource.getEvents();

      expect(adapter.only.path, '/events/list');
    });

    test('the personalised feed is /events/for-you', () async {
      adapter.body = {'items': []};

      await dataSource.getForYouEvents();

      expect(adapter.only.path, '/events/for-you');
    });

    test('following is a filter on the list, and excludes finished events',
        () async {
      adapter.body = {'items': []};

      await dataSource.getFollowingEvents();

      expect(adapter.only.path, '/events/list');
      expect(adapter.only.queryParameters['is_following'], true);
      expect(adapter.only.queryParameters['is_ended'], false);
    });

    test('event details are at /events/info/{id}', () async {
      adapter.body = {'id': 7, 'name': 'Hack Night'};

      await dataSource.getEventDetails(7);

      expect(adapter.only.path, '/events/info/7');
    });

    test('registration posts under the registration sub-router', () async {
      await dataSource.registerForEvent(
        7,
        fullName: 'Aarav Menon',
        email: 'aarav@example.com',
        phone: '9876543210',
        additionalDetails: {'tshirt_size': 'M'},
      );

      expect(adapter.only.path, '/events/registration/7/register');
      expect(adapter.only.method, 'POST');
      final body = adapter.only.data as Map<String, dynamic>;
      expect(body['full_name'], 'Aarav Menon');
      expect(body['email'], 'aarav@example.com');
      expect(body['additional_details'], {'tshirt_size': 'M'});
    });

    test('my registrations is a filter on the list, not its own route',
        () async {
      adapter.body = {'items': []};

      await dataSource.getMyRegistrations();

      expect(adapter.only.path, '/events/list');
      expect(adapter.only.queryParameters['is_registered'], true);
    });

    test('categories are at /events/categories/list', () async {
      adapter.body = <dynamic>[];

      await dataSource.getCategories();

      expect(adapter.only.path, '/events/categories/list');
    });
  });

  group('pagination and filters speak the server dialect', () {
    test('page becomes offset', () async {
      adapter.body = {'items': []};

      await dataSource.getEvents(page: 3, limit: 20);

      expect(adapter.only.queryParameters['offset'], 40);
      expect(adapter.only.queryParameters['limit'], 20);
      expect(adapter.only.queryParameters.containsKey('page'), isFalse);
    });

    test('filters the server does not accept are not sent', () async {
      // /events/list takes is_following, is_registered, is_ended,
      // interest_ids and search. FastAPI ignores anything else, so sending
      // is_online or a date range looked like filtering while returning
      // everything.
      adapter.body = {'items': []};

      await dataSource.getEvents(search: 'robotics', isEnded: false);

      final sent = adapter.only.queryParameters.keys.toSet();
      expect(sent, containsAll(<String>['limit', 'offset', 'search', 'is_ended']));
      expect(sent.intersection({'is_online', 'is_free', 'start_date', 'end_date'}),
          isEmpty);
    });
  });

  group('the response envelope', () {
    test('reads the list from items', () async {
      adapter.body = {
        'total': 1,
        'items': [
          {'id': 7, 'name': 'Hack Night', 'slug': 'hack-night'},
        ],
      };

      final events = await dataSource.getEvents();

      expect(events, hasLength(1));
    });

    test('a results-shaped body yields nothing, which is the old bug',
        () async {
      adapter.body = {
        'results': [
          {'id': 7, 'name': 'Hack Night', 'slug': 'hack-night'},
        ],
      };

      expect(await dataSource.getEvents(), isEmpty);
    });
  });
}
