import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/threads/data/datasources/moderation_remote_datasource.dart';
import 'package:finnet/features/threads/data/models/moderation_models.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
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

const _uuid = '3f2b8c1e-5d4a-4f6b-9a7c-2e1d0b9c8a7f';

void main() {
  late _RecordingAdapter adapter;
  late ModerationRemoteDataSourceImpl dataSource;
  late ModerationRepositoryImpl repository;

  setUp(() {
    adapter = _RecordingAdapter();
    // The app's own error interceptor, so failures arrive shaped as they do
    // in production: a DioException carrying an ApiException.
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    dataSource = ModerationRemoteDataSourceImpl(dio);
    repository = ModerationRepositoryImpl(remoteDataSource: dataSource);
  });

  group('the report body', () {
    test('a post keeps its UUID id as a string', () {
      final body = reportRequestBody(
        const ReportTarget.thread(_uuid),
        ReportReason.spam,
      );
      expect(body, {
        'target_type': 'thread',
        'target_id': _uuid,
        'reason': 'spam',
      });
    });

    test('a numeric id goes as a number', () {
      final body = reportRequestBody(
        ReportTarget.user(42),
        ReportReason.harassment,
      );
      expect(body['target_type'], 'user');
      expect(body['target_id'], 42);
      expect(body['reason'], 'harassment');
    });

    test('a note is trimmed, and left out when blank', () {
      expect(
        reportRequestBody(
          const ReportTarget.comment('c1'),
          ReportReason.other,
          note: '  rude  ',
        )['note'],
        'rude',
      );
      expect(
        reportRequestBody(
          const ReportTarget.comment('c1'),
          ReportReason.other,
          note: '   ',
        ).containsKey('note'),
        isFalse,
      );
    });

    test('every reason is sent as its wire name', () {
      expect(
        ReportReason.values.map((r) => r.name),
        [
          'spam',
          'harassment',
          'hate',
          'sexual',
          'violence',
          'misinformation',
          'other',
        ],
      );
    });
  });

  group('paths match the moderation contract', () {
    test('report: POST /reports', () async {
      adapter
        ..status = 201
        ..body = {'id': 1, 'status': 'open'};

      final result = await repository.report(
        const ReportTarget.comment(_uuid),
        ReportReason.hate,
        note: 'slur',
      );

      expect(result.isRight, isTrue);
      expect(adapter.only.method, 'POST');
      expect(adapter.only.path, '/reports');
      expect(adapter.only.data, {
        'target_type': 'comment',
        'target_id': _uuid,
        'reason': 'hate',
        'note': 'slur',
      });
    });

    test('block: POST /user/blocks with user_id', () async {
      adapter.status = 201;

      final result = await repository.block(7);

      expect(result.isRight, isTrue);
      expect(adapter.only.method, 'POST');
      expect(adapter.only.path, '/user/blocks');
      expect(adapter.only.data, {'user_id': 7});
    });

    test('unblock: DELETE /user/blocks/{user_id}', () async {
      adapter
        ..status = 204
        ..body = null;

      final result = await repository.unblock(7);

      expect(result.isRight, isTrue);
      expect(adapter.only.method, 'DELETE');
      expect(adapter.only.path, '/user/blocks/7');
    });

    test('the blocked list: GET /user/blocks', () async {
      adapter.body = [
        {'user_id': 7, 'name': 'Rahul', 'avatar': 'https://img/r.png'},
        {
          'user_id': '8',
          'name': '  ',
          'avatar': {'thumbnail': 'https://img/t.png', 'original': 'x'},
        },
        // No id: could never be unblocked, so it is dropped.
        {'name': 'Ghost'},
      ];

      final result = await repository.getBlockedUsers();

      expect(adapter.only.method, 'GET');
      expect(adapter.only.path, '/user/blocks');
      expect(result.right, const [
        BlockedUser(userId: 7, name: 'Rahul', avatarUrl: 'https://img/r.png'),
        BlockedUser(
          userId: 8,
          name: 'A follower',
          avatarUrl: 'https://img/t.png',
        ),
      ]);
    });

    test('a list in an envelope is read too, anything else as nobody',
        () async {
      adapter.body = {
        'items': [
          {'user_id': 3, 'name': 'Asha', 'avatar': null},
        ],
      };
      expect((await repository.getBlockedUsers()).right.single.userId, 3);

      adapter.body = 'nope';
      expect((await repository.getBlockedUsers()).right, isEmpty);
    });
  });

  group('failures', () {
    test('a rate-limited report carries 429', () async {
      adapter
        ..status = 429
        ..body = {'error': 'Rate limit exceeded: 5 per 1 minute'};

      final result = await repository.report(
        const ReportTarget.thread(_uuid),
        ReportReason.spam,
      );

      expect(result.isLeft, isTrue);
      expect(result.left.code, '429');
    });

    test('an expired session is an AuthFailure', () async {
      adapter
        ..status = 401
        ..body = {'message': 'Not authenticated'};

      final result = await repository.block(7);

      expect(result.left, isA<AuthFailure>());
      expect(result.left.code, '401');
    });

    test("a refused block keeps the server's words", () async {
      adapter
        ..status = 400
        ..body = {'message': "You can't block yourself"};

      final result = await repository.block(7);

      expect(result.left, isA<ValidationFailure>());
      expect(result.left.message, "You can't block yourself");
    });
  });
}
