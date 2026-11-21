import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/home_widget/data/networking_store.dart';
import 'package:finnet/features/home_widget/data/widget_photos.dart';
import 'package:finnet/features/home_widget/domain/networking.dart';
import 'package:finnet/features/home_widget/presentation/networking_widget_sync.dart';
import 'package:finnet/features/home_widget/presentation/widget_photos_setting.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import '../network/network_fixtures.dart';
import 'widget_fakes.dart';

const _qr = 'https://myotherapp.in/p/abcdefghjk';

String _picture(int id) =>
    'https://media.myotherapp.in/profiles/$id.jpg?X-Amz-Signature=abc$id';

/// One person in the network, with everything the server sends that the
/// widget must never hold: a headline, a company, tags, a note.
Map<String, dynamic> _person(
  int id, {
  String name = 'Ananya Iyer',
  int? userId,
  String? note,
  bool picture = false,
  List<Map<String, dynamic>>? encounters,
}) =>
    {
      'id': id,
      'person': {
        'user_id': userId ?? 100 + id,
        'handle': 'person$id',
        'full_name': name,
        'picture': picture ? _picture(id) : null,
        'headline': 'Staff engineer',
        'org_name': 'Hidden Corp',
      },
      'mutual': false,
      'saved_me': false,
      'note': note,
      'tags': ['investor'],
      'first_met_at': '2026-11-28T10:00:00+05:30',
      'last_met_at': '2026-11-28T10:00:00+05:30',
      'encounters': encounters ??
          [
            {
              'event': devFest(),
              'method': 'qr',
              'met_at': '2026-11-28T10:00:00+05:30',
            },
          ],
    };

NetworkList _page(List<Map<String, dynamic>> items, {int? total}) =>
    NetworkList.fromJson({'items': items, 'total': total ?? items.length});

/// Everything one person on "Recently met" may hold.
const _personFields = {'name', 'initials', 'colour', 'event', 'link', 'photo'};

/// Words from the server's answer that must never reach the widget.
const _never = [
  'Staff engineer',
  'Hidden Corp',
  'investor',
  'a private note',
  'person1', // a handle
  'media.myotherapp.in', // a picture's address
  'X-Amz',
  'asha@example.com',
  '9876543210',
];

final _signedIn = StateProvider<bool>((ref) => true);

void main() {
  group('RecentlyMet', () {
    test('the first four of the page, as read: last met first', () {
      final met = RecentlyMet.from(_page([
        for (var id = 1; id <= 6; id++) _person(id, name: 'Person $id'),
      ]));

      expect(met.people.map((p) => p.name),
          ['Person 1', 'Person 2', 'Person 3', 'Person 4']);
    });

    test('a person: the name, its initials, a colour of their own, the event',
        () {
      final person = RecentlyMet.from(_page([
        _person(7, name: '  Ananya \n Iyer ', userId: 42),
      ])).people.single;

      expect(person.name, 'Ananya Iyer');
      expect(person.initials, 'AI');
      expect(person.colour, 42 % recentlyMetColours);
      expect(person.event, 'DevFest');
      expect(person.link, 'https://myotherapp.in/network/7');
    });

    test('the colour stays with the person, whatever their place in the list',
        () {
      final first = RecentlyMet.from(_page([_person(1), _person(2)]));
      final later = RecentlyMet.from(_page([_person(3), _person(2)]));
      expect(first.people[1].colour, later.people[1].colour);
      for (final p in [...first.people, ...later.people]) {
        expect(p.colour, inInclusiveRange(0, recentlyMetColours - 1));
      }
    });

    test('where they met: the newest meeting at an event; none without one',
        () {
      final met = RecentlyMet.from(_page([
        _person(1, encounters: [
          {'event': null, 'method': 'link', 'met_at': '2026-11-30T10:00:00Z'},
          {
            'event': devFest(),
            'method': 'qr',
            'met_at': '2026-11-28T10:00:00Z'
          },
        ]),
        _person(2, encounters: [
          {'event': null, 'method': 'search', 'met_at': '2026-11-30T10:00:00Z'},
        ]),
      ]));

      expect(met.people[0].event, 'DevFest');
      expect(met.people[1].event, isNull);
      expect(met.people[1].toJson().containsKey('event'), isFalse);
    });

    test('how many on the page have no note yet', () {
      final met = RecentlyMet.from(_page([
        _person(1, note: 'a private note'),
        _person(2),
        _person(3),
        _person(4, note: 'another'),
        _person(5),
      ]));
      expect(met.withoutNote, 3);
      expect(met.people, hasLength(4));
    });

    test('a person\'s link opens their page in the app, signing in first', () {
      final person = RecentlyMet.from(_page([_person(12)])).people.single;
      final location = appLocationForLink(Uri.parse(person.link));
      expect(location, networkPersonRoute(12));
      expect(needsAccount(location!), isTrue);
    });
  });

  group('the JSON', () {
    test('signed in: "met" and "no_note", each person only their fields', () {
      final json = NetworkingSnapshot.from(
        signedIn: true,
        qrLink: _qr,
        recentlyMet: RecentlyMet.from(_page([
          _person(1, note: 'a private note', picture: true),
          _person(2),
        ])),
      ).toJson();

      expect(json['no_note'], 1);
      final met = (json['met'] as List).cast<Map<String, dynamic>>();
      expect(met, hasLength(2));
      for (final person in met) {
        expect(person.keys.toSet().difference(_personFields), isEmpty);
        expect(person.containsKey('photo'), isFalse,
            reason: 'no photo unless one is kept');
      }
      final text = jsonEncode(json);
      for (final word in _never) {
        expect(text, isNot(contains(word)), reason: word);
      }
    });

    test('a kept photo is named by its key, nothing more', () {
      final json = NetworkingSnapshot.from(
        signedIn: true,
        recentlyMet: RecentlyMet.from(_page([_person(1), _person(2)])),
      ).toJson(photos: {1: widgetPhotoKey(1)});

      final met = (json['met'] as List).cast<Map<String, dynamic>>();
      expect(met[0]['photo'], 'networking_photo_1');
      expect(met[1].containsKey('photo'), isFalse);
    });

    test('not read yet: no "met" at all; an empty network: an empty list', () {
      expect(NetworkingSnapshot.from(signedIn: true).toJson().keys,
          isNot(contains('met')));
      final empty = NetworkingSnapshot.from(
          signedIn: true, recentlyMet: RecentlyMet.from(_page([]))).toJson();
      expect(empty['met'], isEmpty);
      expect(empty['no_note'], 0);
    });

    test('signed out: nobody', () {
      final json = NetworkingSnapshot.from(
        signedIn: false,
        recentlyMet: RecentlyMet.from(_page([_person(1)])),
      ).toJson(photos: {1: widgetPhotoKey(1)});
      expect(json.keys.toSet(), {'v', 'state', 'links'});
    });
  });

  group('pictureFingerprint', () {
    test('the same picture through another signed link: the same', () {
      expect(
        pictureFingerprint(
            'https://bucket.s3.amazonaws.com/u/1.jpg?X-Amz-Signature=aaa'),
        pictureFingerprint(
            'https://bucket.s3.amazonaws.com/u/1.jpg?X-Amz-Signature=bbb'),
      );
    });

    test('another picture: another; never the address itself', () {
      final one = pictureFingerprint('https://media.myotherapp.in/u/1.jpg');
      final two = pictureFingerprint('https://media.myotherapp.in/u/2.jpg');
      expect(one, isNot(two));
      expect(one, matches(RegExp(r'^[0-9a-f]{8}$')));
    });
  });

  group('WidgetPhotos', () {
    late MemoryPhotoStore store;
    late FakeThumbnails thumbnails;
    late WidgetPhotos photos;

    setUp(() {
      store = MemoryPhotoStore();
      thumbnails = FakeThumbnails();
      photos = WidgetPhotos(store, thumbnails);
    });

    List<RecentlyMetPerson> people(List<Map<String, dynamic>> items) =>
        RecentlyMet.from(_page(items)).people;

    test('a photo for each person with a picture, made once', () async {
      final shown = people([
        _person(1, picture: true),
        _person(2),
        _person(3, picture: true),
      ]);

      final keys = await photos.keep(shown);
      expect(keys, {1: 'networking_photo_1', 3: 'networking_photo_3'});
      expect(thumbnails.asked, [_picture(1), _picture(3)]);

      await photos.keep(shown);
      expect(thumbnails.asked, hasLength(2), reason: 'already kept');
    });

    test('a new picture makes a new photo', () async {
      await photos.keep(people([_person(1, picture: true)]));
      final changed = RecentlyMetPerson(
        id: 1,
        name: 'Ananya Iyer',
        initials: 'AI',
        colour: 0,
        picture: 'https://media.myotherapp.in/profiles/1-new.jpg',
      );
      await photos.keep([changed]);
      expect(thumbnails.asked, hasLength(2));
    });

    test('without downloading: only the photos already kept', () async {
      await photos.keep(people([_person(1, picture: true)]));
      final keys = await photos.keep(
          people([_person(1, picture: true), _person(2, picture: true)]),
          download: false);
      expect(keys, {1: 'networking_photo_1'});
      expect(thumbnails.asked, [_picture(1)]);
    });

    test('a picture that can\'t be had: initials', () async {
      thumbnails.failing.add(_picture(1));
      expect(await photos.keep(people([_person(1, picture: true)])), isEmpty);
      expect(store.files, isEmpty);
    });

    test('everyone else\'s photo is deleted', () async {
      await photos
          .keep(people([_person(1, picture: true), _person(2, picture: true)]));
      await photos.dropAllBut(['networking_photo_2']);
      expect(store.files.keys, ['networking_photo_2']);
    });

    test('deleted while one was being made: none kept', () async {
      thumbnails.gate = Completer();
      final making = photos.keep(people([_person(1, picture: true)]));
      await Future<void>.delayed(Duration.zero);
      await photos.removeAll();
      thumbnails.gate!.complete();

      expect(await making, isEmpty);
      expect(store.files, isEmpty);
    });

    test('clear: every photo, and the switch off', () async {
      store.on = true;
      await photos.keep(people([_person(1, picture: true)]));
      await clearWidgetPhotos(photos);
      expect(store.files, isEmpty);
      expect(store.on, isFalse);
    });
  });

  group('NetworkingWidgetSync with photos', () {
    late MemoryWidgetStore widget;
    late MemoryPhotoStore store;
    late FakeThumbnails thumbnails;
    late NetworkingWidgetSync sync;

    setUp(() {
      widget = MemoryWidgetStore();
      store = MemoryPhotoStore();
      thumbnails = FakeThumbnails();
      sync =
          NetworkingWidgetSync(widget, photos: WidgetPhotos(store, thumbnails));
    });

    NetworkingSnapshot shown(List<Map<String, dynamic>> items) =>
        NetworkingSnapshot.from(
            signedIn: true, recentlyMet: RecentlyMet.from(_page(items)));

    List<Map<String, dynamic>> met() =>
        (widget.last['met'] as List).cast<Map<String, dynamic>>();

    test('photos on: kept first, then named in the JSON', () async {
      await sync.show(shown([_person(1, picture: true), _person(2)]),
          photos: true);

      expect(store.files.keys, ['networking_photo_1']);
      expect(met()[0]['photo'], 'networking_photo_1');
      expect(met()[1].containsKey('photo'), isFalse);
    });

    test('photos off: initials, and every kept photo deleted', () async {
      await sync.show(shown([_person(1, picture: true)]), photos: true);
      await sync.show(shown([_person(1, picture: true)]), photos: false);

      expect(met()[0].containsKey('photo'), isFalse);
      expect(store.files, isEmpty);
      expect(thumbnails.asked, hasLength(1));
    });

    test('not known yet: the kept photos stay, and none is made', () async {
      await sync.show(shown([_person(1, picture: true)]), photos: true);
      await sync.show(
          shown([_person(1, picture: true), _person(2, picture: true)]),
          photos: null);

      expect(met()[0]['photo'], 'networking_photo_1');
      expect(met()[1].containsKey('photo'), isFalse);
      expect(thumbnails.asked, [_picture(1)]);
      expect(store.files.keys, ['networking_photo_1']);
    });

    test('someone who left the four: their photo is deleted', () async {
      await sync.show(
          shown([_person(1, picture: true), _person(2, picture: true)]),
          photos: true);
      await sync.show(shown([_person(2, picture: true)]), photos: true);

      expect(store.files.keys, ['networking_photo_2']);
      expect(store.removes, ['networking_photo_1']);
    });

    test('a write waiting for photos never lands after a newer one', () async {
      thumbnails.gate = Completer();
      final slow = sync.show(shown([_person(1, picture: true)]), photos: true);
      await Future<void>.delayed(Duration.zero);
      final signedOut = sync.signedOut();
      thumbnails.gate!.complete();
      await slow;
      await signedOut;

      expect(widget.writes, hasLength(1));
      expect(widget.last['state'], 'signed_out');
      expect(store.files, isEmpty);
    });

    test('signing out: nobody, and every photo deleted', () async {
      await sync.show(shown([_person(1, picture: true)]), photos: true);
      await sync.signedOut();

      expect(widget.last.keys.toSet(), {'v', 'state', 'links'});
      expect(store.files, isEmpty);
    });
  });

  group('the photos switch', () {
    test('off by default, kept when turned on', () async {
      final store = MemoryPhotoStore();
      final setting =
          WidgetPhotosSetting(WidgetPhotos(store, FakeThumbnails()));
      expect(setting.state, isNull, reason: 'until the choice is read');
      await setting.loaded;
      expect(setting.state, isFalse);

      await setting.set(true);
      expect(setting.state, isTrue);
      expect(store.on, isTrue);
      expect(store.files, isEmpty, reason: 'nothing made by the switch');
    });

    test('turned off: every photo deleted at once, the widget redrawn',
        () async {
      final store = MemoryPhotoStore()..on = true;
      final photos = WidgetPhotos(store, FakeThumbnails());
      await photos
          .keep(RecentlyMet.from(_page([_person(1, picture: true)])).people);
      var redraws = 0;
      final setting =
          WidgetPhotosSetting(photos, redraw: () async => redraws++);
      await setting.loaded;
      expect(setting.state, isTrue);

      await setting.set(false);
      expect(store.on, isFalse);
      expect(store.files, isEmpty);
      expect(redraws, 1);
    });

    test('a phone without the widgets\' storage: off, and nothing kept',
        () async {
      final store = HomeWidgetPhotoStore(supported: false);
      await store.setOn(true);
      expect(await store.isOn(), isFalse);
      await store.save('networking_photo_1', 'f', Uint8List(3));
      expect(await store.saved(), isEmpty);
    });
  });

  group('roundThumbnail', () {
    testWidgets('a picture becomes a small round photo, clear in the corners',
        (tester) async {
      await tester.runAsync(() async {
        // A 300 x 200 red picture.
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 300, 200),
            Paint()..color = const Color(0xFFFF0000));
        final source = await recorder.endRecording().toImage(300, 200);
        final encoded =
            (await source.toByteData(format: ui.ImageByteFormat.png))!
                .buffer
                .asUint8List();

        final png = await roundThumbnail(encoded);
        expect(png, isNotNull);

        final codec = await ui.instantiateImageCodec(png!);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, widgetPhotoSide);
        expect(image.height, widgetPhotoSide);
        final pixels =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int alphaAt(int x, int y) =>
            pixels.getUint8((y * widgetPhotoSide + x) * 4 + 3);
        expect(alphaAt(0, 0), 0, reason: 'outside the circle');
        expect(alphaAt(widgetPhotoSide ~/ 2, widgetPhotoSide ~/ 2), 255);
      });
    });

    testWidgets('something that isn\'t a picture: none', (tester) async {
      await tester.runAsync(() async {
        expect(await roundThumbnail(Uint8List.fromList([1, 2, 3])), isNull);
      });
    });
  });

  group('NetworkingWidgetSyncScope, "Recently met"', () {
    late MemoryWidgetStore widget;
    late MemoryPhotoStore store;
    late FakeThumbnails thumbnails;
    late RouteAdapter api;
    late ProviderContainer container;

    Future<void> run(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(
      WidgetTester tester, {
      bool placed = true,
      bool photosOn = false,
      List<List<Map<String, dynamic>>>? answers,
    }) async {
      widget = MemoryWidgetStore()..placed = placed;
      store = MemoryPhotoStore()..on = photosOn;
      thumbnails = FakeThumbnails();
      api = useFakeApi()
        ..on('GET', '/me/qr', {'code': 'abcdefghjk', 'url': _qr})
        ..on('GET', '/me/profile', myProfileJson());
      // Each read of the network answers the next page; the last stays.
      for (final items in answers ??
          [
            [
              _person(1, name: 'Ravi Kumar', picture: true),
              _person(2, name: 'Meera Das', note: 'a private note'),
              _person(3, name: 'Arjun Nair', picture: true),
            ],
          ]) {
        api.on('GET', '/network', {'items': items, 'total': items.length});
      }
      await tester.pumpWidget(ProviderScope(
        overrides: [
          networkingStoreProvider.overrideWithValue(widget),
          widgetPhotoStoreProvider.overrideWithValue(store),
          widgetThumbnailsProvider.overrideWithValue(thumbnails),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          isAuthenticatedProvider.overrideWith((ref) => ref.watch(_signedIn)),
        ],
        child: const MaterialApp(
          home: NetworkingWidgetSyncScope(child: Text('the tabs')),
        ),
      ));
      container =
          ProviderScope.containerOf(tester.element(find.text('the tabs')));
      await run(tester);
    }

    List<Map<String, dynamic>> met() =>
        (widget.last['met'] as List).cast<Map<String, dynamic>>();

    testWidgets('placed: the people met last, and the notes still to write',
        (tester) async {
      await pump(tester);

      expect(met().map((p) => p['name']),
          ['Ravi Kumar', 'Meera Das', 'Arjun Nair']);
      expect(met().map((p) => p['initials']), ['RK', 'MD', 'AN']);
      expect(met().first['event'], 'DevFest');
      expect(met().first['link'], 'https://myotherapp.in/network/1');
      expect(widget.last['no_note'], 2);
      for (final json in widget.writes) {
        for (final word in _never) {
          expect(json, isNot(contains(word)), reason: word);
        }
      }
    });

    testWidgets('photos off (the default): initials, and no picture fetched',
        (tester) async {
      await pump(tester);

      expect(met().every((p) => !p.containsKey('photo')), isTrue);
      expect(thumbnails.asked, isEmpty);
      expect(store.files, isEmpty);
    });

    testWidgets('photos on: a photo of each person with a picture',
        (tester) async {
      await pump(tester, photosOn: true);

      expect(thumbnails.asked, [_picture(1), _picture(3)]);
      expect(store.files.keys,
          unorderedEquals(['networking_photo_1', 'networking_photo_3']));
      expect(met()[0]['photo'], 'networking_photo_1');
      expect(met()[1].containsKey('photo'), isFalse);
      expect(met()[2]['photo'], 'networking_photo_3');
    });

    testWidgets('turned off in Settings: every photo gone, initials again',
        (tester) async {
      await pump(tester, photosOn: true);
      expect(store.files, isNotEmpty);

      await container.read(widgetPhotosSettingProvider.notifier).set(false);
      await run(tester);

      expect(store.files, isEmpty);
      expect(met().every((p) => !p.containsKey('photo')), isTrue);
      expect(widget.redraws, greaterThan(0));
    });

    testWidgets('no widget on a home screen: nobody\'s name, no photo',
        (tester) async {
      await pump(tester, placed: false, photosOn: true);

      // Even after the Network tab read the page last met first.
      final page =
          container.listen(networkListProvider(recentlyMetQuery), (_, __) {});
      await run(tester);
      page.close();

      expect(widget.last.containsKey('met'), isFalse);
      expect(thumbnails.asked, isEmpty);
      for (final json in widget.writes) {
        expect(json, isNot(contains('Ravi')));
      }
    });

    testWidgets('a note written, a person removed: the widget follows',
        (tester) async {
      await pump(tester, answers: [
        [
          _person(1, name: 'Ravi Kumar'),
          _person(2, name: 'Meera Das'),
          _person(3, name: 'Arjun Nair'),
        ],
        [
          _person(1, name: 'Ravi Kumar', note: 'met at the Flutter booth'),
          _person(3, name: 'Arjun Nair'),
        ],
      ]);
      expect(widget.last['no_note'], 3);

      // A note saved, or someone removed: the network is read again.
      container.invalidate(networkListProvider);
      await run(tester);

      expect(met().map((p) => p['name']), ['Ravi Kumar', 'Arjun Nair']);
      expect(widget.last['no_note'], 1);
      expect(widget.last['network'], 2);
    });

    testWidgets('signing out: nobody\'s name, and the photos gone',
        (tester) async {
      await pump(tester, photosOn: true);
      expect(store.files, isNotEmpty);

      container.read(_signedIn.notifier).state = false;
      await run(tester);

      expect(widget.last.keys.toSet(), {'v', 'state', 'links'});
      expect(store.files, isEmpty);
    });
  });
}
