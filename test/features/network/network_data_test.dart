import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/data/save_queue.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'network_fixtures.dart';

/// No signal: every request fails before an answer.
class _NoSignal implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketException('No route to host'),
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [inner], calling [first] as the first request goes out.
class _OnFirstRequest implements HttpClientAdapter {
  _OnFirstRequest(this.inner, this.first);
  final HttpClientAdapter inner;
  void Function()? first;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    final call = first;
    first = null;
    call?.call();
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _body(RequestOptions r) =>
    r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const {};

void main() {
  group('profiles', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    test('mine, a change, the links', () async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('PATCH', '/me/profile', myProfileJson(handle: 'asha.m'))
        ..on(
            'PUT',
            '/me/profile/links',
            myProfileJson(links: [
              {'type': 'github', 'url': 'https://github.com/asha'},
            ]));
      final profiles = ProfilesApi();
      expect((await profiles.me()).handle, 'asha');
      expect((await profiles.update({'handle': 'asha.m'})).handle, 'asha.m');
      expect(
          _body(api.sent('PATCH', '/me/profile').single), {'handle': 'asha.m'});

      final mine = await profiles.putLinks([
        ProfileLink(type: 'github', uri: Uri.parse('https://github.com/asha')),
        ProfileLink(
            type: 'website', uri: Uri.parse('https://asha.dev'), label: 'Blog'),
      ]);
      expect(mine.profile.links.single.type, 'github');
      expect(_body(api.sent('PUT', '/me/profile/links').single), {
        'links': [
          {'type': 'github', 'url': 'https://github.com/asha'},
          {'type': 'website', 'url': 'https://asha.dev', 'label': 'Blog'},
        ],
      });
    });

    test('a taken handle is thrown with its code', () async {
      api.on('PATCH', '/me/profile',
          {'message': 'Taken', 'error_code': handleTakenCode},
          status: 409);
      Object? error;
      try {
        await ProfilesApi().update({'handle': 'ananya'});
      } catch (e) {
        error = e;
      }
      expect(handleErrorMessage(error), 'Someone already has that handle.');
    });

    test('projects: add, change, order, delete', () async {
      api
        ..on('POST', '/me/profile/projects', {'id': 9, 'title': 'Club app'})
        ..on(
            'PATCH', '/me/profile/projects/9', {'id': 9, 'title': 'Club app 2'})
        // The order answers the whole profile (the backend's notes).
        ..on(
            'PUT',
            '/me/profile/projects/order',
            myProfileJson(projects: [
              {'id': 9, 'title': 'Club app 2'},
              {'id': 3, 'title': 'Older one'},
            ]))
        ..on('DELETE', '/me/profile/projects/9', null, status: 204);
      final profiles = ProfilesApi();
      final added =
          await profiles.addProject(const ProfileProject(title: 'Club app'));
      expect(added.id, 9);
      expect(
          (await profiles.updateProject(
                  9, const ProfileProject(title: 'Club app 2')))
              .title,
          'Club app 2');
      final ordered = await profiles.orderProjects([9, 3]);
      expect(ordered.profile.projects.map((p) => p.id), [9, 3]);
      expect(_body(api.sent('PUT', '/me/profile/projects/order').single), {
        'ids': [9, 3]
      });
      await profiles.deleteProject(9);
      expect(api.sent('DELETE', '/me/profile/projects/9'), hasLength(1));
    });

    test("the backend's other refusals, in words", () {
      ApiException refused(String code, {Map<String, dynamic>? errors}) =>
          ApiException.fromResponse(
              422, {'message': 'No', 'error_code': code, 'errors': errors});
      String words(String code) =>
          profileEditErrorMessage(refused(code), fallback: 'fallback');
      expect(words(projectLimitCode), contains('12 projects'));
      expect(words(orderInvalidCode), contains('changed meanwhile'));
      expect(
          words(notAnImageCode), "That file isn't a picture. Choose a photo.");
      expect(words(orgNotFoundCode), contains('organisation'));
      expect(words(linkInvalidCode), contains('https://'));
      expect(words(handleTakenCode), 'Someone already has that handle.');
      // A save refused for going too fast says how long to wait.
      expect(
          saveErrorMessage(ApiException.fromResponse(429, {
            'message': 'Slow down',
            'error_code': rateLimitedCode,
            'errors': {'retry_after': 20},
          })),
          contains('Wait 20 seconds'));
      // Scanning off refuses saving by QR; the profile link still works.
      expect(saveErrorMessage(refused(profileScanningOffCode)),
          contains('profile link'));
    });

    test('a refused order puts the projects back, and reads them again',
        () async {
      api
        ..on(
            'GET',
            '/me/profile',
            myProfileJson(projects: [
              {'id': 3, 'title': 'Older one'},
              {'id': 9, 'title': 'Club app'},
            ]))
        ..on('PUT', '/me/profile/projects/order',
            {'message': 'No', 'error_code': orderInvalidCode},
            status: 422);
      final notifier = MyProfileNotifier(ProfilesApi());
      addTearDown(notifier.dispose);
      await notifier.load();
      final order = notifier.state.profile!.profile.projects.reversed.toList();
      await expectLater(notifier.reorderProjects(order), throwsA(anything));
      expect(notifier.state.profile!.profile.projects.map((p) => p.id), [3, 9]);
      await pumpEventQueue();
      expect(api.sent('GET', '/me/profile'), hasLength(2));
    });

    test('my QR, and replacing it', () async {
      api
        ..on('GET', '/me/qr', {
          'code': 'abcdefghjk',
          'url': 'https://myotherapp.in/p/abcdefghjk',
          'created_at': '2026-11-14T10:00:00Z',
        })
        ..on('POST', '/me/qr/replace', {
          'code': 'mnpqrstuvw',
          'url': 'https://myotherapp.in/p/mnpqrstuvw',
        });
      expect((await ProfilesApi().myQr()).code, 'abcdefghjk');
      expect((await ProfilesApi().replaceQr()).code, 'mnpqrstuvw');
    });

    test('after Replace, My QR read with no signal is the new code', () async {
      APIService.instance.dio.interceptors.insert(0, ApiCacheInterceptor());
      api
        ..on('GET', '/me/qr', {
          'code': 'abcdefghjk',
          'url': 'https://myotherapp.in/p/abcdefghjk',
          'created_at': '2026-11-14T10:00:00Z',
        })
        ..on('POST', '/me/qr/replace', {
          'code': 'mnpqrstuvw',
          'url': 'https://myotherapp.in/p/mnpqrstuvw',
          'created_at': '2026-11-14T11:00:00Z',
        });
      // The old one is on the phone; it is replaced; then no signal.
      await ProfilesApi().myQr();
      await ProfilesApi().replaceQr();
      APIService.instance.dio.httpClientAdapter = _NoSignal();
      expect((await ProfilesApi().myQr()).code, 'mnpqrstuvw');
    });

    test('a public profile, anonymously too, and one not there', () async {
      api.on('GET', '/profiles/ananya', publicProfileJson());
      final found = await ProfilesApi().profile('ananya');
      expect((found as ProfileFound).profile.fullName, 'Ananya Iyer');
      await ProfilesApi().profile('ananya', anonymous: true);
      expect(
          api.sent('GET', '/profiles/ananya').last.extra['skipAuth'], isTrue);
      expect(await ProfilesApi().profile('gone'), isA<ProfileMissing>());
    });

    test('a code: found, replaced, scanning off, unknown', () async {
      api
        ..on('GET', '/profiles/by-code/abcdefghjk',
            {'handle': 'ananya', 'profile': publicProfileJson()})
        ..on('GET', '/profiles/by-code/oldoldoldo',
            {'message': 'Gone', 'error_code': profileCodeInactiveCode},
            status: 410)
        ..on('GET', '/profiles/by-code/offoffoffo',
            {'message': 'Off', 'error_code': profileScanningOffCode},
            status: 403);
      final profiles = ProfilesApi();
      expect(await profiles.byCode('abcdefghjk'), isA<CodeFound>());
      expect(await profiles.byCode('oldoldoldo'), isA<CodeInactive>());
      expect(await profiles.byCode('offoffoffo'), isA<CodeScanningOff>());
      expect(await profiles.byCode('nobodynobo'), isA<CodeMissing>());
    });
  });

  group('the network', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    test('save by code, at an event', () async {
      api.on('POST', '/network', saveResultJson());
      final saved = await NetworkApi()
          .save(code: 'abcdefghjk', method: MetHow.qr, eventId: 9);
      expect(saved.person.id, 5);
      expect(_body(api.sent('POST', '/network').single),
          {'code': 'abcdefghjk', 'method': 'qr', 'event_id': 9});
    });

    test('list with filters, a person, a note, remove, saved me', () async {
      api
        ..on('GET', '/network', networkListJson([networkPersonJson()]))
        ..on('GET', '/network/5', networkPersonJson())
        ..on('PATCH', '/network/5', networkPersonJson(note: 'Riverpod'))
        ..on('DELETE', '/network/5', null, status: 204)
        ..on('GET', '/network/saved-me', {
          'items': [
            {'person': personBriefJson(), 'saved_at': null, 'event': devFest()},
          ],
          'total': 1,
        });
      final network = NetworkApi();
      final list = await network
          .list(const NetworkQuery(eventId: 9, sort: NetworkSort.name));
      expect(list.items.single.person.fullName, 'Ananya Iyer');
      expect(api.sent('GET', '/network').single.queryParameters,
          containsPair('event_id', 9));
      expect((await network.person(5)).id, 5);
      expect((await network.update(5, note: ' Riverpod ')).note, 'Riverpod');
      expect(
          _body(api.sent('PATCH', '/network/5').single), {'note': 'Riverpod'});
      await network.remove(5);
      final savedMe = await network.savedMe(eventId: 9);
      expect(savedMe.total, 1);
      expect(savedMe.items.single.event!.name, 'DevFest');
    });

    test('a refused save says why', () async {
      api.on('POST', '/network',
          {'message': 'No', 'error_code': cannotSaveSelfCode},
          status: 422);
      final saver = NetworkSaver(NetworkApi(), MemoryPendingSaveStore());
      final attempt = await saver.save(code: 'abcdefghjk', method: MetHow.qr);
      expect(attempt, isA<SaveRefused>());
      expect((attempt as SaveRefused).message, "That's your own code.");
    });
  });

  group('pictures are signed links that expire', () {
    test('a copy answered with no signal comes without them', () async {
      final api = useFakeApi();
      // The app's own order: the saved copy answers before the error is read.
      APIService.instance.dio.interceptors.insert(0, ApiCacheInterceptor());
      final person = networkPersonJson();
      (person['person'] as Map)['picture'] =
          'https://bucket.s3.amazonaws.com/u/1.jpg?X-Amz-Signature=abc';
      api.on('GET', '/network', networkListJson([person]));

      final fresh = await NetworkApi().list(const NetworkQuery());
      expect(fresh.items.single.person.picture, isNotNull);

      APIService.instance.dio.httpClientAdapter = _NoSignal();
      final offline = await NetworkApi().list(const NetworkQuery());
      expect(offline.items.single.person.fullName, 'Ananya Iyer');
      expect(offline.items.single.person.picture, isNull);
    });

    test('withoutPictures takes out every picture and image, at any depth', () {
      expect(
          withoutPictures({
            'person': {'picture': 'x', 'name': 'A'},
            'projects': [
              {'image': 'y', 'title': 'T'},
            ],
          }),
          {
            'person': {'name': 'A'},
            'projects': [
              {'title': 'T'},
            ],
          });
    });
  });

  group('saves with no signal', () {
    test('are kept with their time, then sent once there is one', () async {
      final store = MemoryPendingSaveStore();
      final noSignal = _NoSignal();
      useFakeApi();
      APIService.instance.dio.httpClientAdapter = noSignal;
      var synced = 0;
      final at = DateTime.utc(2026, 11, 28, 4, 30);
      final saver = NetworkSaver(NetworkApi(), store,
          now: () => at, onSynced: () => synced++);

      final attempt =
          await saver.save(code: 'abcdefghjk', method: MetHow.qr, eventId: 9);
      expect(attempt, isA<SavedLater>());
      expect(saver.state.count, 1);
      // The same person again keeps one.
      await saver.save(code: 'abcdefghjk', method: MetHow.qr, eventId: 9);
      expect(store.saved, hasLength(1));

      // Still no signal: kept.
      expect(await saver.drain(), 0);
      expect(store.saved, hasLength(1));

      final api = useFakeApi();
      api.on('POST', '/network', saveResultJson());
      expect(await saver.drain(), 1);
      expect(store.saved, isEmpty);
      expect(saver.state.count, 0);
      expect(synced, 1);
      expect(_body(api.sent('POST', '/network').single), {
        'code': 'abcdefghjk',
        'method': 'qr',
        'event_id': 9,
        'met_at': '2026-11-28T04:30:00.000Z',
      });
    });

    test('one refused for good is dropped; the rest still go', () async {
      final store = MemoryPendingSaveStore();
      await store.add(PendingSave(
          clientRef: 'a',
          code: 'oldoldoldo',
          method: MetHow.qr,
          metAt: DateTime(2026)));
      await store.add(PendingSave(
          clientRef: 'b',
          handle: 'ananya',
          method: MetHow.discovery,
          metAt: DateTime(2026)));
      final api = useFakeApi();
      api
        ..on('POST', '/network',
            {'message': 'Gone', 'error_code': profileCodeInactiveCode},
            status: 410)
        ..on('POST', '/network', saveResultJson());
      final saver = NetworkSaver(NetworkApi(), store,
          now: () => DateTime(2026, 1, 1, 10));
      expect(await saver.drain(), 1);
      expect(store.saved, isEmpty);
      // They were told "Saved, it'll sync": now they hear it wasn't.
      final notice = saver.state.notices.single;
      expect(notice.kind, SaveNoticeKind.refused);
      expect(notice.save.code, 'oldoldoldo');
      expect(notice.message, contains('no longer active'));
      expect(store.told, hasLength(1));
      await saver.dismissNotices();
      expect(saver.state.notices, isEmpty);
      expect(store.told, isEmpty);
    });

    test('past 72 hours: saved now, without the event, and said so', () async {
      final store = MemoryPendingSaveStore();
      await store.add(PendingSave(
          clientRef: 'a',
          code: 'abcdefghjk',
          method: MetHow.qr,
          eventId: 9,
          metAt: DateTime.utc(2026, 11, 28, 10)));
      final api = useFakeApi()..on('POST', '/network', saveResultJson());
      final saver = NetworkSaver(NetworkApi(), store,
          now: () => DateTime.utc(2026, 12, 1, 11));
      expect(await saver.drain(), 1);
      expect(_body(api.sent('POST', '/network').single),
          {'code': 'abcdefghjk', 'method': 'qr'});
      expect(saver.state.notices.single.kind, SaveNoticeKind.late);
    });

    test("another account's waiting saves are not sent as this one", () async {
      final store = MemoryPendingSaveStore();
      await store.add(PendingSave(
          clientRef: 'a',
          code: 'abcdefghjk',
          method: MetHow.qr,
          metAt: DateTime.utc(2026, 11, 28, 10),
          ownerId: 1));
      final api = useFakeApi()..on('POST', '/network', saveResultJson());
      final saver = NetworkSaver(NetworkApi(), store,
          ownerId: 2, now: () => DateTime.utc(2026, 11, 28, 11));
      expect(await saver.drain(), 0);
      expect(api.sent('POST', '/network'), isEmpty);
      expect(saver.state.count, 0);
      // Theirs is still there, for them.
      expect(store.saved, hasLength(1));
    });

    test('signed out mid-send: the rest are not sent', () async {
      final store = MemoryPendingSaveStore();
      for (final ref in ['a', 'b']) {
        await store.add(PendingSave(
            clientRef: ref,
            handle: 'person-$ref',
            method: MetHow.discovery,
            metAt: DateTime.utc(2026, 11, 28, 10)));
      }
      final api = useFakeApi()..on('POST', '/network', saveResultJson());
      final saver = NetworkSaver(NetworkApi(), store,
          now: () => DateTime.utc(2026, 11, 28, 11));
      // The session ends while the first is on its way.
      APIService.instance.dio.httpClientAdapter =
          _OnFirstRequest(api, () => saver.dispose());
      await saver.drain();
      expect(api.sent('POST', '/network'), hasLength(1));
      expect(store.saved.single.clientRef, 'b');
    });

    test('a waiting save remembers whose it is', () async {
      final store = MemoryPendingSaveStore();
      useFakeApi();
      APIService.instance.dio.httpClientAdapter = _NoSignal();
      final saver = NetworkSaver(NetworkApi(), store, ownerId: 7);
      await saver.save(code: 'abcdefghjk', method: MetHow.qr);
      expect(store.saved.single.ownerId, 7);
      expect(PendingSave.fromJson(store.saved.single.toJson())!.ownerId, 7);
    });

    test('the file store keeps them across restarts', () async {
      final dir = await Directory.systemTemp.createTemp('saves');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/network_saves.json');
      final store = FilePendingSaveStore(file: () async => file);
      await store.add(PendingSave(
          clientRef: 'a',
          code: 'abcdefghjk',
          method: MetHow.qr,
          eventId: 9,
          metAt: DateTime.utc(2026, 11, 28)));
      final again = FilePendingSaveStore(file: () async => file);
      final saved = await again.all();
      expect(saved.single.code, 'abcdefghjk');
      expect(saved.single.eventId, 9);
      expect((jsonDecode(await file.readAsString()) as Map)['pending'],
          hasLength(1));
      // A notice stays with the file, and survives the save's removal.
      await again.addNotice(SaveNotice(
          kind: SaveNoticeKind.refused,
          save: saved.single,
          message: 'Gone',
          at: DateTime.utc(2026, 11, 29)));
      await again.remove(['a']);
      final third = FilePendingSaveStore(file: () async => file);
      expect(await third.all(), isEmpty);
      expect((await third.notices()).single.message, 'Gone');
      await third.clearNotices();
      expect(await file.exists(), isFalse);
      await third.add(saved.single);
      await third.clear();
      expect(await third.all(), isEmpty);
    });
  });
}
