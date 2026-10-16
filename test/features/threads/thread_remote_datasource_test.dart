import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/threads/data/datasources/thread_remote_datasource.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object? body = const <String, dynamic>{};
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
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
  late ThreadRemoteDataSourceImpl dataSource;
  late ThreadRepositoryImpl repository;

  setUp(() {
    adapter = _RecordingAdapter();
    // The app's own error interceptor, so failures arrive shaped as they do
    // in production: a DioException carrying an ApiException.
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    dataSource = ThreadRemoteDataSourceImpl(dio);
    repository = ThreadRepositoryImpl(remoteDataSource: dataSource);
  });

  group('paths and bodies match app/api/threads/router.py', () {
    test("a club's posts: GET /clubs/{id}/threads with offset and limit",
        () async {
      adapter.body = {'items': [], 'total': 0, 'limit': 20, 'offset': 40};

      await dataSource.getClubThreads(5, offset: 40, limit: 20);

      expect(adapter.only.method, 'GET');
      expect(adapter.only.path, '/clubs/5/threads');
      expect(adapter.only.queryParameters, {'offset': 40, 'limit': 20});
    });

    test('one post: GET /threads/{id}', () async {
      adapter.body = {'id': 't1'};

      await dataSource.getThread('t1');

      expect(adapter.only.method, 'GET');
      expect(adapter.only.path, '/threads/t1');
    });

    test('like: POST /threads/{id}/like', () async {
      adapter.body = {'liked': true, 'likes': 1};

      final result = await dataSource.toggleLike('t1');

      expect(adapter.only.method, 'POST');
      expect(adapter.only.path, '/threads/t1/like');
      expect(result.liked, isTrue);
    });

    test('vote: POST /threads/{id}/vote with option_id', () async {
      adapter.body = {
        'options': [
          {'id': 'a', 'label': 'A', 'votes': 1, 'share': 100},
        ],
        'votes': 1,
        'voted_option_id': 'a',
      };

      final poll = await dataSource.vote('t1', 'a');

      expect(adapter.only.method, 'POST');
      expect(adapter.only.path, '/threads/t1/vote');
      expect(adapter.only.data, {'option_id': 'a'});
      expect(poll.votedOptionId, 'a');
    });

    test('comments: GET /threads/{id}/comments, a bare list', () async {
      adapter.body = [
        {
          'id': 'c1',
          'body': 'hi',
          'author': {'id': 1, 'name': 'A', 'is_club': false},
          'created_at': '2026-10-16T09:00:00Z',
        },
      ];

      final comments = await dataSource.getComments('t1');

      expect(adapter.only.path, '/threads/t1/comments');
      expect(comments.single.body, 'hi');
    });

    test('comments that are not a list read as none', () async {
      adapter.body = {'items': []};

      expect(await dataSource.getComments('t1'), isEmpty);
    });

    test('comment: POST /threads/{id}/comments with body', () async {
      adapter.status = 201;
      adapter.body = {
        'id': 'c9',
        'body': 'Count me in',
        'author': {'id': 1, 'name': 'A', 'is_club': false},
        'created_at': '2026-10-16T09:00:00Z',
      };

      final comment = await dataSource.addComment('t1', 'Count me in');

      expect(adapter.only.method, 'POST');
      expect(adapter.only.path, '/threads/t1/comments');
      expect(adapter.only.data, {'body': 'Count me in'});
      expect(comment.id, 'c9');
    });

    test('delete: DELETE /threads/{id}/comments/{comment_id}', () async {
      adapter.body = {'deleted': true};

      await dataSource.deleteComment('t1', 'c9');

      expect(adapter.only.method, 'DELETE');
      expect(adapter.only.path, '/threads/t1/comments/c9');
    });

    test('an id from a notification is escaped, not trusted', () async {
      adapter.body = {'id': 'x'};

      await dataSource.getThread('../clubs/1');

      expect(adapter.only.path, '/threads/..%2Fclubs%2F1');
    });
  });

  group('the repository reports failures a person can read', () {
    test('a removed post fails with code 404', () async {
      adapter.status = 404;
      adapter.body = {'message': 'Post not found'};

      final result = await repository.getThread('gone');

      expect(result.isLeft, isTrue);
      expect(result.left.code, '404');
      // The server's own words, via error_utils, not generic copy.
      expect(result.left.message, 'Post not found');
    });

    test("a refused comment carries the server's message", () async {
      adapter.status = 422;
      adapter.body = {'message': 'Write something first'};

      final result = await repository.addComment('t1', ' ');

      expect(result.left.message, 'Write something first');
    });

    test('an expired session is an AuthFailure coded 401', () async {
      adapter.status = 401;
      adapter.body = {'message': 'Not authenticated'};

      final result = await repository.toggleLike('t1');

      expect(result.left, isA<AuthFailure>());
      expect(result.left.code, '401');
    });

    test('deleting someone else\'s comment is coded 403, not 401', () async {
      adapter.status = 403;
      adapter.body = {
        'message':
            'Only the person who wrote it, or the club, can remove a comment',
      };

      final result = await repository.deleteComment('t1', 'c1');

      expect(result.left, isA<AuthFailure>());
      expect(result.left.code, '403');
      expect(result.left.message, contains('Only the person who wrote it'));
    });

    test('a 200 with an empty post is treated as removed', () async {
      adapter.body = <String, dynamic>{};

      final result = await repository.getThread('t1');

      expect(result.left.code, '404');
    });

    test('a page arrives as entities, with paging worked out', () async {
      adapter.body = {
        'items': [
          {'id': 't1', 'club': {'id': 5, 'name': 'C'}, 'body': 'b'},
        ],
        'total': 25,
        'limit': 20,
        'offset': 0,
      };

      final page = (await repository.getClubThreads(5)).right;

      expect(page.items.single.id, 't1');
      expect(page.hasMore, isTrue);
    });
  });
}
