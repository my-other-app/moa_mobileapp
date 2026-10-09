import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/features/clubs/data/datasources/club_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the request Dio was about to make and answers with a canned body,
/// without any network.
///
/// The point of these tests is the request, not the response: the previous
/// data source addressed eight routes the server does not have, sent `page`
/// where it reads `offset`, and unpacked `results` from an envelope whose
/// list is `items`. All of that is invisible to a test that only checks the
/// parsed output, and all of it shipped.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object body = const <String, dynamic>{};
  int statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
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
  late ClubRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    dataSource = ClubRemoteDataSourceImpl(dio);
  });

  group('paths match app/api/clubs/router.py', () {
    test('the club list is /clubs/list', () async {
      adapter.body = {'items': []};

      await dataSource.getClubs();

      expect(adapter.only.path, '/clubs/list');
      expect(adapter.only.method, 'GET');
    });

    test('following is a filter on the list, not its own route', () async {
      adapter.body = {'items': []};

      await dataSource.getFollowingClubs();

      expect(adapter.only.path, '/clubs/list');
      expect(adapter.only.queryParameters['is_following'], true);
    });

    test('pinned is a filter too', () async {
      adapter.body = {'items': []};

      await dataSource.getPinnedClubs();

      expect(adapter.only.path, '/clubs/list');
      expect(adapter.only.queryParameters['is_pinned'], true);
    });

    test('search is a filter on the list, with the key the server reads',
        () async {
      adapter.body = {'items': []};

      await dataSource.searchClubs('robotics');

      expect(adapter.only.path, '/clubs/list');
      // `search`, not `q`.
      expect(adapter.only.queryParameters['search'], 'robotics');
    });

    test('club details are at /clubs/info/{id}', () async {
      adapter.body = {'id': 7, 'name': 'Makers', 'slug': 'makers'};

      await dataSource.getClubDetails(7);

      expect(adapter.only.path, '/clubs/info/7');
    });

    test('follow is POST /clubs/follow/{id}', () async {
      await dataSource.followClub(7);

      expect(adapter.only.path, '/clubs/follow/7');
      expect(adapter.only.method, 'POST');
    });

    test('unfollow is POST /clubs/unfollow/{id}, not DELETE on follow',
        () async {
      await dataSource.unfollowClub(7);

      expect(adapter.only.path, '/clubs/unfollow/7');
      expect(adapter.only.method, 'POST');
    });

    test('pin is POST /clubs/pin/{id}', () async {
      adapter.body = {'is_pinned': true};

      await dataSource.togglePin(7);

      expect(adapter.only.path, '/clubs/pin/7');
      expect(adapter.only.method, 'POST');
    });

    test('hide is POST /clubs/hide/{id}', () async {
      adapter.body = {'is_hidden': true};

      await dataSource.toggleHide(7);

      expect(adapter.only.path, '/clubs/hide/7');
    });
  });

  group('pagination speaks the server dialect', () {
    test('page becomes offset', () async {
      adapter.body = {'items': []};

      await dataSource.getClubs(page: 3, limit: 20);

      expect(adapter.only.queryParameters['limit'], 20);
      // Page 3 of 20 starts at 40, and there is no `page` parameter at all.
      expect(adapter.only.queryParameters['offset'], 40);
      expect(adapter.only.queryParameters.containsKey('page'), isFalse);
    });

    test('page 1 starts at offset 0', () async {
      adapter.body = {'items': []};

      await dataSource.getClubs(page: 1, limit: 10);

      expect(adapter.only.queryParameters['offset'], 0);
    });

    test('no page means the first page', () async {
      adapter.body = {'items': []};

      await dataSource.getClubs();

      expect(adapter.only.queryParameters['offset'], 0);
      expect(adapter.only.queryParameters['limit'], 10);
    });
  });

  group('the response envelope', () {
    test('reads the list from items', () async {
      adapter.body = {
        'total': 1,
        'has_next': false,
        'items': [
          {
            'id': 7,
            'name': 'Makers',
            'slug': 'makers',
            'followers_count': 12,
            'is_following': true,
          },
        ],
      };

      final clubs = await dataSource.getClubs();

      expect(clubs, hasLength(1));
      expect(clubs.single.name, 'Makers');
    });

    test('a results-shaped body yields nothing, which is the old bug', () async {
      // Kept as a test because it is the failure mode that hid for so long:
      // reading the wrong key returns an empty list and no error, so the
      // screen looks like a club with no entries rather than a broken call.
      adapter.body = {
        'results': [
          {'id': 7, 'name': 'Makers', 'slug': 'makers'},
        ],
      };

      expect(await dataSource.getClubs(), isEmpty);
    });

    test('the toggle answers with the new state', () async {
      adapter.body = {'club_id': 7, 'is_pinned': false};

      expect(await dataSource.togglePin(7), isFalse);
    });
  });
}
