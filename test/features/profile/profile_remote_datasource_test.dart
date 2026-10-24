import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

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

const _profileBody = {
  'id': 1,
  'full_name': 'Aarav Menon',
  'email': 'aarav@example.com',
};

void main() {
  late _RecordingAdapter adapter;
  late ProfileRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    dataSource = ProfileRemoteDataSourceImpl(dio);
  });

  group('paths match app/api/users/router.py', () {
    test('the profile is at /user/profile/me', () async {
      adapter.body = _profileBody;

      await dataSource.getMyProfile();

      expect(adapter.only.path, '/user/profile/me');
    });

    test('updating is POST /user/profile/update, not PUT /user/profile',
        () async {
      adapter.body = _profileBody;

      await dataSource.updateProfile(
        const UpdateProfileRequest(fullName: 'Aarav Menon'),
      );

      expect(adapter.only.path, '/user/profile/update');
      expect(adapter.only.method, 'POST');
    });

    test('creating is POST /user/profile/create', () async {
      adapter.body = _profileBody;

      await dataSource.createProfile(
        const CreateProfileRequest(
          fullName: 'Aarav Menon',
          whatsapp: '9876543210',
          organizationId: 1,
        ),
      );

      expect(adapter.only.path, '/user/profile/create');
    });

    test('organizations are at /orgs/list', () async {
      adapter.body = {'items': []};

      await dataSource.getOrganizations();

      expect(adapter.only.path, '/orgs/list');
    });

    test('avatars are at /user/avatar/list', () async {
      adapter.body = <dynamic>[];

      await dataSource.getAvatars();

      expect(adapter.only.path, '/user/avatar/list');
    });

    test('selecting an avatar is POST /user/avatar/select', () async {
      adapter.body = {'id': 3, 'name': 'img3', 'image': {}};

      await dataSource.selectAvatar(3);

      expect(adapter.only.path, '/user/avatar/select');
      expect(adapter.only.method, 'POST');
      expect(adapter.only.data, {'avatar_id': 3});
    });

    test('its answer is the avatar, not a profile', () async {
      // It was read as a profile: one with the avatar's id and name.
      adapter.body = {
        'id': 3,
        'name': 'img3',
        'image': {'thumbnail': 'https://cdn.test/a3.thumbnail.png'},
      };

      final avatar = await dataSource.selectAvatar(3);

      expect(avatar.id, 3);
      expect(avatar.image.thumbnail, 'https://cdn.test/a3.thumbnail.png');
    });

    test('selecting interests is POST /user/interests/select', () async {
      adapter.body = _profileBody;

      await dataSource.updateInterests([1, 2]);

      expect(adapter.only.path, '/user/interests/select');
    });
  });

  group('envelopes', () {
    test('a paginated organization list is read from items', () async {
      // Reading the body as a list returned nothing, with no error, when it
      // was an envelope.
      adapter.body = {
        'items': [
          {'id': 1, 'name': 'CET'},
        ],
      };

      expect(await dataSource.getOrganizations(), hasLength(1));
    });

    test('a bare array still works', () async {
      adapter.body = [
        {'id': 1, 'name': 'CET'},
      ];

      expect(await dataSource.getOrganizations(), hasLength(1));
    });
  });
}
