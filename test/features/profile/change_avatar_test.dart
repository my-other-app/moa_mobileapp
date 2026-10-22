import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:finnet/features/profile/data/photo_picker.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:finnet/features/profile/presentation/widgets/my_picture.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_comment_tile.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A picture cache that never answers: every picture stays loading, and
/// nothing reaches a platform channel.
class _Slow extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key, Map<String, String>? headers, bool? withProgress}) =>
      StreamController<FileResponse>().stream;

  @override
  Future<FileInfo?> getFileFromCache(String key,
          {bool ignoreMemCache = false}) async =>
      null;
}

Avatar _avatar(int id) => Avatar(
      id: id,
      name: 'img$id',
      image: ImageUrls(
        original: 'https://cdn.test/avatars/a$id.png',
        medium: 'https://cdn.test/avatars/a$id.medium.png',
        thumbnail: 'https://cdn.test/avatars/a$id.thumbnail.png',
      ),
    );

const _oldPhoto = ImageUrls(
  original: 'https://s3.test/users/profile_pic/old.jpg?X-Amz-Signature=1',
  medium: 'https://s3.test/users/profile_pic/old.medium.jpg?X-Amz-Signature=1',
  thumbnail:
      'https://s3.test/users/profile_pic/old.thumbnail.jpg?X-Amz-Signature=1',
);

const _newPhoto = ImageUrls(
  original: 'https://s3.test/users/profile_pic/new.jpg?X-Amz-Signature=2',
  medium: 'https://s3.test/users/profile_pic/new.medium.jpg?X-Amz-Signature=2',
  thumbnail:
      'https://s3.test/users/profile_pic/new.thumbnail.jpg?X-Amz-Signature=2',
);

UserProfile _profile({Avatar? avatar, ImageUrls? photo}) => UserProfile(
      id: '7',
      fullName: 'Asha Menon',
      email: 'asha@example.com',
      avatar: avatar,
      photo: photo,
    );

/// The server, holding each picture change until the test answers it.
class _Profiles implements ProfileRepository {
  _Profiles(this.profile);

  UserProfile profile;
  List<Avatar>? savedAvatars;
  Result<List<Avatar>> avatars = Either.right([_avatar(1), _avatar(2)]);
  final selects = <(int, Completer<Result<Avatar>>)>[];
  final uploads = <(String, Completer<Result<ImageUrls?>>)>[];

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(profile);

  @override
  Future<UserProfile?> getSavedProfile() async => null;

  @override
  Future<List<Avatar>?> getSavedAvatars() async => savedAvatars;

  @override
  Future<Result<List<Avatar>>> getAvatars() async => avatars;

  @override
  Future<Result<Avatar>> selectAvatar(int avatarId) {
    final answer = Completer<Result<Avatar>>();
    selects.add((avatarId, answer));
    return answer.future;
  }

  @override
  Future<Result<ImageUrls?>> uploadPicture(String path) {
    final answer = Completer<Result<ImageUrls?>>();
    uploads.add((path, answer));
    return answer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Picker implements PhotoPicker {
  _Picker({this.path, this.failure});

  final String? path;
  final PhotoPickFailure? failure;
  final asked = <PhotoSource>[];

  @override
  Future<String?> pick(PhotoSource source) async {
    asked.add(source);
    if (failure != null) throw failure!;
    return path;
  }
}

/// A page with the person's picture on it and a way to the sheet.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            const MyPicture(key: ValueKey('header'), size: 60),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => changeAvatar(context),
                child: const Text('Change Avatar'),
              ),
            ),
          ],
        ),
      );
}

void main() {
  late _Profiles server;
  late _Picker picker;
  late List<List<String>> evicted;

  setUp(() {
    AppImageCaches.debugOverride(public: _Slow(), private: _Slow());
    evicted = [];
  });
  tearDown(AppImageCaches.debugOverride);

  Future<void> pump(WidgetTester tester, UserProfile profile,
      {_Picker? photoPicker}) async {
    server = _Profiles(profile);
    picker = photoPicker ?? _Picker();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(server),
        photoPickerProvider.overrideWithValue(picker),
        pictureEvictorProvider.overrideWithValue((urls) async {
          evicted.add(urls);
        }),
      ],
      child: const MaterialApp(home: _Host()),
    ));
    await tester.pump();
    await tester.pump();
  }

  /// The address the header's picture is drawn from, or null for none.
  String? header(WidgetTester tester) {
    final images = find.descendant(
        of: find.byKey(const ValueKey('header')),
        matching: find.byType(AppNetworkImage));
    if (images.evaluate().isEmpty) return null;
    return tester.widget<AppNetworkImage>(images).url;
  }

  bool headerShowsLocal(WidgetTester tester) => find
      .descendant(
          of: find.byKey(const ValueKey('header')),
          matching: find.byKey(MyPicture.localKey))
      .evaluate()
      .isNotEmpty;

  /// The sheet gone: while a photo uploads its spinner never settles.
  Future<void> closed(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Change Avatar'));
    await tester.pumpAndSettle();
  }

  group('the sheet', () {
    testWidgets('lists the preset avatars, the one in use ticked',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(2)));
      await openSheet(tester);

      expect(find.text('CHANGE AVATAR'), findsOneWidget);
      expect(find.byKey(ChangeAvatarSheet.tileKey(1)), findsOneWidget);
      expect(find.byKey(ChangeAvatarSheet.tileKey(2)), findsOneWidget);
      final tick = find.byKey(const ValueKey('avatar-choice-tick'));
      expect(tick, findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(ChangeAvatarSheet.tileKey(2)), matching: tick),
          findsOneWidget);
      // Both ways to a photo.
      expect(find.byKey(ChangeAvatarSheet.cameraKey), findsOneWidget);
      expect(find.byKey(ChangeAvatarSheet.libraryKey), findsOneWidget);
    });

    testWidgets('fits a small phone with many avatars, scrolling them',
        (tester) async {
      tester.view.physicalSize = const Size(640, 1136); // iPhone SE (1st)
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pump(tester, _profile(avatar: _avatar(1)));
      server.avatars = Either.right([for (var i = 1; i <= 24; i++) _avatar(i)]);
      await openSheet(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(ChangeAvatarSheet.cameraKey), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(ChangeAvatarSheet.tileKey(24)), 100,
          scrollable: find.byType(Scrollable).last);
      expect(find.byKey(ChangeAvatarSheet.tileKey(24)), findsOneWidget);
    });

    testWidgets('with a photo up, no avatar is ticked', (tester) async {
      await pump(tester, _profile(avatar: _avatar(2), photo: _oldPhoto));
      await openSheet(tester);

      expect(find.byKey(const ValueKey('avatar-choice-tick')), findsNothing);
      expect(find.text('Or pick an avatar instead of your photo'),
          findsOneWidget);
    });

    testWidgets('the saved list shows even when the server cannot be reached',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)));
      server.savedAvatars = [_avatar(1), _avatar(3)];
      server.avatars = Either.left(const NetworkFailure(message: 'offline'));
      await openSheet(tester);

      expect(find.byKey(ChangeAvatarSheet.tileKey(3)), findsOneWidget);
      expect(find.text("Couldn't load the avatars."), findsNothing);
    });

    testWidgets('nothing saved and no network: says so, and can try again',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)));
      server.avatars = Either.left(const NetworkFailure(message: 'offline'));
      await openSheet(tester);

      expect(find.text("Couldn't load the avatars."), findsOneWidget);
      server.avatars = Either.right([_avatar(4)]);
      await tester.tap(find.byKey(ChangeAvatarSheet.retryKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ChangeAvatarSheet.tileKey(4)), findsOneWidget);
    });
  });

  group('picking a preset', () {
    testWidgets('the header changes at once, before the server answers',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)));
      expect(header(tester), _avatar(1).image.thumbnail);
      await openSheet(tester);

      await tester.tap(find.byKey(ChangeAvatarSheet.tileKey(2)));
      await tester.pumpAndSettle();

      expect(find.text('CHANGE AVATAR'), findsNothing, reason: 'closed');
      expect(server.selects.single.$1, 2);
      expect(header(tester), _avatar(2).image.thumbnail,
          reason: 'not waiting for the server');

      server.selects.single.$2.complete(Either.right(_avatar(2)));
      server.profile = _profile(avatar: _avatar(2));
      await tester.pumpAndSettle();
      expect(header(tester), _avatar(2).image.thumbnail);
    });

    testWidgets('refused: the old picture comes back, with a message',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.tileKey(2)));
      await tester.pumpAndSettle();
      expect(header(tester), _avatar(2).image.thumbnail);

      server.selects.single.$2
          .complete(Either.left(const ServerFailure(message: 'boom')));
      await tester.pumpAndSettle();

      expect(header(tester), _avatar(1).image.thumbnail);
      expect(find.text("Couldn't change your picture. Try again in a moment."),
          findsOneWidget);
    });

    testWidgets(
        'the server saved it but answered 500 (production today): it stays, '
        'with no error', (tester) async {
      // POST /user/avatar/select commits, then reads the avatar back
      // lazily, which the async session cannot: a 500 for a pick that
      // stuck. Onboarding's old sheet showed an error for it, and left the
      // person stuck on "select profile pic to proceed".
      await pump(tester, _profile(avatar: _avatar(1)));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.tileKey(2)));
      await tester.pumpAndSettle();

      server.profile = _profile(avatar: _avatar(2));
      server.selects.single.$2.complete(Either.left(const ServerFailure(
          message: 'Something went wrong on our side.')));
      await tester.pumpAndSettle();

      expect(header(tester), _avatar(2).image.thumbnail);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'a server that keeps the uploaded photo in front: the photo shows, '
        'and it says so', (tester) async {
      await pump(tester, _profile(avatar: _avatar(1), photo: _oldPhoto));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.tileKey(2)));
      await tester.pumpAndSettle();

      server.profile = _profile(avatar: _avatar(2), photo: _oldPhoto);
      server.selects.single.$2.complete(Either.right(_avatar(2)));
      await tester.pumpAndSettle();

      expect(header(tester), _oldPhoto.thumbnail);
      expect(find.textContaining('your uploaded photo still shows'),
          findsOneWidget);
      expect(evicted, isEmpty, reason: 'the photo is still in use');
    });

    testWidgets('offline: put back, and says why', (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.tileKey(2)));
      await tester.pumpAndSettle();

      server.selects.single.$2
          .complete(Either.left(const NetworkFailure(message: 'offline')));
      await tester.pumpAndSettle();

      expect(header(tester), _avatar(1).image.thumbnail);
      expect(find.textContaining("You're offline, so your picture wasn't"),
          findsOneWidget);
    });

    testWidgets('over a photo: replaces it, and the old photo leaves the cache',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1), photo: _oldPhoto));
      expect(header(tester), _oldPhoto.thumbnail);
      await openSheet(tester);

      await tester.tap(find.byKey(ChangeAvatarSheet.tileKey(2)));
      await tester.pumpAndSettle();
      expect(header(tester), _avatar(2).image.thumbnail);

      server.profile = _profile(avatar: _avatar(2));
      server.selects.single.$2.complete(Either.right(_avatar(2)));
      await tester.pumpAndSettle();

      expect(header(tester), _avatar(2).image.thumbnail);
      expect(evicted.single, containsAll(_oldPhoto.allUrls));
    });
  });

  group('uploading a photo', () {
    testWidgets(
        'shown from the phone at once, then the uploaded copy; the old one '
        'leaves the cache', (tester) async {
      await pump(tester, _profile(avatar: _avatar(1), photo: _oldPhoto),
          photoPicker: _Picker(path: '/tmp/picked.jpg'));
      await openSheet(tester);

      await tester.tap(find.byKey(ChangeAvatarSheet.libraryKey));
      await closed(tester);

      expect(picker.asked, [PhotoSource.library]);
      expect(server.uploads.single.$1, '/tmp/picked.jpg');
      expect(headerShowsLocal(tester), isTrue, reason: 'before the server');
      expect(find.byKey(MyPicture.uploadingKey), findsOneWidget);

      server.profile = _profile(avatar: _avatar(1), photo: _newPhoto);
      server.uploads.single.$2.complete(Either.right(_newPhoto));
      await tester.pumpAndSettle();

      expect(find.byKey(MyPicture.uploadingKey), findsNothing);
      expect(header(tester), _newPhoto.thumbnail);
      expect(evicted.single, containsAll(_oldPhoto.allUrls));
      expect(find.text('Your new photo is up.'), findsOneWidget);
    });

    testWidgets('a 500 for an upload that went in still counts',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)),
          photoPicker: _Picker(path: '/tmp/picked.jpg'));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.libraryKey));
      await closed(tester);

      server.profile = _profile(avatar: _avatar(1), photo: _newPhoto);
      server.uploads.single.$2
          .complete(Either.left(const ServerFailure(message: 'oops')));
      await tester.pumpAndSettle();

      expect(header(tester), _newPhoto.thumbnail);
      expect(find.text('Your new photo is up.'), findsOneWidget);
    });

    testWidgets('from the camera', (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)),
          photoPicker: _Picker(path: '/tmp/selfie.jpg'));
      await openSheet(tester);

      await tester.tap(find.byKey(ChangeAvatarSheet.cameraKey));
      await closed(tester);

      expect(picker.asked, [PhotoSource.camera]);
      expect(server.uploads.single.$1, '/tmp/selfie.jpg');
    });

    testWidgets('refused: the old picture comes back, with the reason',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)),
          photoPicker: _Picker(path: '/tmp/huge.jpg'));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.libraryKey));
      await closed(tester);
      expect(headerShowsLocal(tester), isTrue);

      server.uploads.single.$2.complete(Either.left(const ValidationFailure(
          message: 'That image is over 5 MB. Export it smaller and try '
              'again.')));
      await tester.pumpAndSettle();

      expect(headerShowsLocal(tester), isFalse);
      expect(find.byKey(MyPicture.uploadingKey), findsNothing);
      expect(header(tester), _avatar(1).image.thumbnail);
      expect(find.textContaining('That image is over 5 MB'), findsOneWidget);
    });

    testWidgets('backing out of the picker changes nothing', (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)), photoPicker: _Picker());
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.libraryKey));
      await tester.pumpAndSettle();

      expect(server.uploads, isEmpty);
      expect(header(tester), _avatar(1).image.thumbnail);
    });

    testWidgets('no access to the photos: says how to allow it',
        (tester) async {
      await pump(tester, _profile(avatar: _avatar(1)),
          photoPicker: _Picker(
              failure: PhotoPickFailure(DevicePhotoPicker.messageFor(
                  'photo_access_denied', PhotoSource.library))));
      await openSheet(tester);
      await tester.tap(find.byKey(ChangeAvatarSheet.libraryKey));
      await tester.pumpAndSettle();

      expect(server.uploads, isEmpty);
      expect(find.textContaining('Photo access is off for MyOtherApp'),
          findsOneWidget);
    });
  });

  group('where it is', () {
    testWidgets('tapping the picture on Profile opens the picker',
        (tester) async {
      // A phone's height: the loading shimmer is drawn for a phone.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      server = _Profiles(_profile(avatar: _avatar(1)));
      await tester.pumpWidget(ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(server)],
        child: const MaterialApp(home: ProfilePage()),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Change Avatar'), findsOneWidget, reason: 'the menu');
      await tester.tap(find.byKey(ProfilePage.pictureKey));
      await tester.pumpAndSettle();

      expect(find.text('CHANGE AVATAR'), findsOneWidget);
      expect(find.byKey(ChangeAvatarSheet.tileKey(1)), findsOneWidget);
    });
  });

  group('everywhere at once', () {
    testWidgets('their own comments show the picture they have now',
        (tester) async {
      final comment = ThreadComment(
        id: 'c1',
        body: 'See you there',
        authorId: 7,
        authorName: 'Asha Menon',
        authorAvatarUrl: 'https://s3.test/the-picture-it-was-loaded-with.png',
        createdAt: DateTime(2026, 10, 22),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ThreadCommentTile(
            comment: comment,
            ownPictureUrl: _avatar(2).image.thumbnail,
          ),
        ),
      ));

      expect(tester.widget<ThreadClubAvatar>(find.byType(ThreadClubAvatar))
          .logoUrl, _avatar(2).image.thumbnail);
    });
  });

  group('the data source', () {
    late _Adapter adapter;
    late ApiCache cache;
    late ProfileRemoteDataSourceImpl remote;

    setUp(() {
      adapter = _Adapter();
      cache =
          ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiCacheInterceptor(cache));
      remote = ProfileRemoteDataSourceImpl(dio, cache: cache);
    });

    test(
        'a photo is PUT /user/profile/update-picture as profile_picture, '
        'sent as an image', () async {
      adapter.answers['PUT /user/profile/update-picture'] = {
        'thumbnail': _newPhoto.thumbnail,
        'medium': _newPhoto.medium,
        'original': _newPhoto.original,
      };
      final dir = await Directory.systemTemp.createTemp('avatar');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/picked.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);

      final urls = await remote.uploadPicture(file.path);

      final sent = adapter.requests.single;
      expect(sent.method, 'PUT');
      final form = sent.data as FormData;
      expect(form.files.single.key, 'profile_picture');
      expect(form.files.single.value.filename, 'picked.jpg');
      expect(form.files.single.value.contentType.toString(), 'image/jpeg');
      expect(urls?.medium, _newPhoto.medium);
    });

    test('the saved profile takes the new picture, for offline and restarts',
        () async {
      adapter.answers['GET /user/profile/me'] = {
        'id': 7,
        'full_name': 'Asha Menon',
        'profile': {
          'full_name': 'Asha Menon',
          'avatar': {'id': 1, 'name': 'img1', 'image': {}},
          'profile_pic': {'medium': _oldPhoto.medium},
        },
      };
      await remote.getMyProfile();
      adapter.answers['POST /user/avatar/select'] = {
        'id': 2,
        'name': 'img2',
        'image': {'thumbnail': _avatar(2).image.thumbnail},
      };

      await remote.selectAvatar(2);

      final saved = (await remote.getSavedProfile())!.toEntity();
      expect(saved.avatar?.id, 2);
      expect(saved.photo, isNull);
      expect(saved.pictureUrl(small: true), _avatar(2).image.thumbnail);
    });

    test('the avatars are saved for next time', () async {
      adapter.answers['GET /user/avatar/list'] = [
        {'id': 1, 'name': 'img1', 'image': {}},
      ];
      expect(await remote.getSavedAvatars(), isNull);

      await remote.getAvatars();

      expect((await remote.getSavedAvatars())!.single.id, 1);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final answers = <String, Object>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(answers['${options.method} ${options.path}']),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
