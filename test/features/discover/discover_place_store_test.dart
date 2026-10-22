import 'dart:io';

import 'package:finnet/features/discover/data/datasources/discover_place_store.dart';
import 'package:finnet/features/discover/domain/discover_cities.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _tvm = DiscoverWhere(
  city: 'Thiruvananthapuram',
  region: 'Kerala',
  lat: 8.48333,
  lng: 76.91667,
  source: WhereSource.ip,
);

const _mumbai = DiscoverWhere(
  city: 'Mumbai',
  region: 'Maharashtra',
  lat: 19.0728,
  lng: 72.8826,
  source: WhereSource.ip,
);

final _kochi = discoverCities.firstWhere((c) => c.slug == 'kochi');

void main() {
  group('which place wins', () {
    test("the connection's first guess is kept, to about 100 m", () {
      final store = MemoryDiscoverPlaceStore();
      final places = DiscoverPlaceNotifier(store)..guessed(_tvm);

      expect(places.place?.city, 'Thiruvananthapuram');
      expect(places.place?.point, (lat: 8.483, lng: 76.917));
      expect(store.place, places.place);
      // Keeping a guess is not a change the lists are read again for.
      expect(places.state.changes, 0);
    });

    test('a later guess never replaces the kept one', () {
      // Wi-Fi at home, then mobile data behind the carrier's Mumbai address.
      final places = DiscoverPlaceNotifier(MemoryDiscoverPlaceStore())
        ..guessed(_tvm)
        ..guessed(_mumbai);
      expect(places.place?.city, 'Thiruvananthapuram');
    });

    test('only a placed guess from the connection is kept', () {
      final places = DiscoverPlaceNotifier(MemoryDiscoverPlaceStore())
        ..guessed(DiscoverWhere.unknown)
        ..guessed(const DiscoverWhere(
            lat: 9.93, lng: 76.27, source: WhereSource.browser));
      expect(places.place, isNull);
    });

    test('a picked city beats the guess; guessing again forgets it', () {
      final store = MemoryDiscoverPlaceStore();
      final places = DiscoverPlaceNotifier(store)..guessed(_tvm);

      places.pick(_kochi);
      expect(places.place?.city, 'Kochi');
      expect(places.place?.source, WhereSource.picked);
      expect(places.state.changes, 1);
      // A guess arriving after does not move it.
      places.guessed(_mumbai);
      expect(places.place?.city, 'Kochi');

      places.guessAgain();
      expect(places.place, isNull);
      expect(store.place, isNull);
      expect(places.state.changes, 2);
      // The next guess is kept again.
      places.guessed(_mumbai);
      expect(places.place?.city, 'Mumbai');
    });

    test('a new session starts from the kept place', () {
      final store = MemoryDiscoverPlaceStore();
      DiscoverPlaceNotifier(store).pick(_kochi);
      expect(DiscoverPlaceNotifier(store).place?.city, 'Kochi');
    });

    test('each city is a picked place with a point', () {
      for (final c in discoverCities) {
        expect(c.where.isPlaced, isTrue, reason: c.slug);
        expect(c.where.explanation, 'You picked ${c.name}.');
      }
    });
  });

  group('the file', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('discover_place_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<FileDiscoverPlaceStore> open() =>
        FileDiscoverPlaceStore.open(directory: () async => dir);

    test('a phone that never had a place has none', () async {
      expect((await open()).place, isNull);
    });

    test('survives a restart', () async {
      await (await open()).keep(_kochi.where);
      expect((await open()).place, _kochi.where);
    });

    test('forgetting deletes it', () async {
      final store = await open();
      await store.keep(_tvm);
      await store.keep(null);
      expect(store.place, isNull);
      expect((await open()).place, isNull);
    });

    test('a damaged file is no place', () async {
      await File('${dir.path}/${FileDiscoverPlaceStore.fileName}')
          .writeAsString('{"city": "Kochi", "lat": "x"');
      expect((await open()).place, isNull);
    });
  });
}
