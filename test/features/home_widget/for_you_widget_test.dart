import 'dart:convert';
import 'dart:io';

import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/datasources/discover_place_store.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/home_widget/data/for_you_store.dart';
import 'package:finnet/features/home_widget/domain/events_for_you.dart';
import 'package:finnet/features/home_widget/presentation/for_you_widget_sync.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'widget_fakes.dart';

const _api = 'https://api.myotherapp.in/api/v1';

/// The front page the widgets are tested on, and what each picks from it
/// (the same files check ForYouData.swift and ForYouData.kt).
const _homeFile = 'test/fixtures/widgets/for_you_home.json';
const _expectedFile = 'test/fixtures/widgets/for_you_expected.json';

/// 10:00 on Tuesday 24 November 2026, in India.
final _now = DateTime.utc(2026, 11, 24, 4, 30);

DiscoverHome _home() =>
    parseHome(jsonDecode(File(_homeFile).readAsStringSync()));

/// Everything a listed event may carry (docs/HOME_WIDGETS.md).
const _itemKeys = {
  'id',
  'name',
  'starts_at',
  'ends_at',
  'weekday',
  'day',
  'month',
  'time',
  'date',
  'club',
  'place',
  'link',
};

const _topKeys = {
  'v',
  'state',
  'header',
  'items',
  'see_all',
  'ask',
  'fetched_at',
};

/// The cases the three sides are held to.
List<Map<String, Object?>> _cases(DiscoverHome home) {
  Map<String, Object?> run(String name, DiscoverHome h, List<int> topics) {
    final pick = pickFromHome(h, ForYouAsk(api: _api, topics: topics), _now);
    return {
      'name': name,
      'topics': topics,
      'header': pick.header?.words,
      'items': [for (final e in pick.events) e.toJson()],
    };
  }

  return [
    run('topics', home, [3]),
    run('no topics', home, []),
    run('design topic', home, [5]),
    run('popular only',
        DiscoverHome(where: home.where, popular: home.popular), []),
    run(
        'later only',
        DiscoverHome(
            where: home.where,
            popular: [
              for (final e in home.popular)
                if (e.id == 108 || e.id == 109) e,
            ]),
        [5]),
    run('nothing', const DiscoverHome(), [3]),
  ];
}

class _Profiles extends FakeProfileRepository {
  _Profiles(List<int> topics) {
    profile = UserProfile(
      id: 'u-1',
      fullName: 'Asha Menon',
      email: 'asha@example.com',
      interests: [
        for (final t in topics) Interest(id: 100 + t, name: 'i$t', categoryId: t),
      ],
    );
  }
}

final _signedIn = StateProvider<bool>((ref) => true);

void main() {
  group('pickForYou', () {
    test('the three sides pick the same: the expected file', () {
      final expected = jsonDecode(File(_expectedFile).readAsStringSync());
      final actual = {'now': _now.millisecondsSinceEpoch, 'cases': _cases(_home())};
      // To write the file again after a change of rules:
      //   WRITE_FOR_YOU=1 flutter test test/features/home_widget/for_you_widget_test.dart
      if (Platform.environment['WRITE_FOR_YOU'] == '1') {
        File(_expectedFile).writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert(actual)}\n');
      }
      expect(jsonDecode(jsonEncode(actual)), expected);
    });

    List<int> ids(ForYouPick pick) => [for (final e in pick.events) e.id];

    test('this week first -- their topics, then near them -- then popular', () {
      final pick = pickFromHome(_home(), const ForYouAsk(api: _api, topics: [3]), _now);
      // 101 is in Tech (3); 105 is near (3 km); 103 online, 104 190 km off;
      // then the popular ones in Tech (107, 108) before the rest.
      expect(ids(pick), [101, 105, 103, 104, 107, 108]);
      expect(pick.header, ForYouHeader.forYou);
    });

    test('no topics: the near ones lead, and the header says so', () {
      final pick = pickFromHome(_home(), const ForYouAsk(api: _api), _now);
      expect(ids(pick), [105, 101, 103, 104, 107, 108]);
      expect(pick.header, ForYouHeader.nearYou);
    });

    test('an event already over is never listed', () {
      final pick = pickFromHome(_home(), const ForYouAsk(api: _api, topics: [3]), _now);
      // 102, this morning's yoga, ended at 8:00.
      expect(ids(pick), isNot(contains(102)));
      // Nine days on, this week's events are over; the photo walk on 6
      // December is now this week, and near.
      final later = pickFromHome(_home(), const ForYouAsk(api: _api),
          _now.add(const Duration(days: 9)));
      expect(ids(later), [106, 108]);
      expect(later.header, ForYouHeader.nearYou);
    });

    test('each event once, at most six', () {
      final pick = pickFromHome(_home(), const ForYouAsk(api: _api), _now);
      expect(ids(pick).toSet(), hasLength(ids(pick).length));
      expect(pick.events, hasLength(forYouLimit));
    });

    test('few events: popular across the platform fills in', () {
      final home = _home();
      final pick = pickFromHome(
          DiscoverHome(where: home.where, popular: home.popular),
          const ForYouAsk(api: _api),
          _now);
      expect(ids(pick), [107, 101, 108, 109]);
    });

    test('nothing on: empty, with no header', () {
      final pick =
          pickFromHome(const DiscoverHome(), const ForYouAsk(api: _api), _now);
      expect(pick.events, isEmpty);
      expect(pick.header, isNull);
    });
  });

  group('the JSON', () {
    Map<String, dynamic> snapshot({List<int> topics = const [3]}) {
      final ask = ForYouAsk.about(
        api: _api,
        topics: topics,
        place: const DiscoverWhere(
            city: 'Kochi', lat: 9.93123, lng: 76.26734, source: WhereSource.ip),
      );
      return jsonDecode(jsonEncode(ForYouSnapshot(
        pick: pickFromHome(_home(), ask, _now),
        ask: ask,
        fetchedAt: _now,
      ).toJson())) as Map<String, dynamic>;
    }

    test('holds only what the widget shows and where to ask again', () {
      final json = snapshot();
      expect(json.keys.toSet(), _topKeys);
      expect(json['v'], 1);
      expect(json['state'], 'events');
      expect(json['header'], 'For you');
      expect(json['see_all'], 'https://myotherapp.in/events');
      for (final item in json['items'] as List) {
        expect((item as Map).keys.toSet().difference(_itemKeys), isEmpty);
      }
      final text = jsonEncode(json);
      // Nothing the front page carries that the widget doesn't show.
      for (final kept in ['poster', 'cdn.example', 'going', 'fee', 'distance',
          'topics":[{', 'summary', 'lat":9.931']) {
        expect(text, isNot(contains(kept)));
      }
    });

    test('the place to two decimals (the city), the topics by id', () {
      final ask = snapshot()['ask'] as Map;
      expect(ask, {
        'api': _api,
        'topics': [3],
        'city': 'Kochi',
        'lat': 9.93,
        'lng': 76.27,
      });
    });

    test('an event: its page, its club, its place or Online', () {
      final items = snapshot()['items'] as List;
      final first = items.first as Map;
      expect(first['name'], 'Flutter Kochi Meetup');
      expect(first['club'], 'Kochi Coders');
      expect(first['place'], 'Maker Space, Kochi');
      expect(first['weekday'], 'WED');
      expect(first['day'], '25');
      expect(first['month'], 'NOV');
      expect(first['time'], '6:00 pm');
      final online = items.firstWhere((i) => i['id'] == 103) as Map;
      expect(online['place'], 'Online');
      for (final item in items) {
        final link = Uri.parse((item as Map)['link'] as String);
        // The app's own page for the event, which needs no account.
        expect(link.scheme, 'https');
        expect(link.host, 'myotherapp.in');
        expect(appLocationForLink(link), startsWith('/events/'));
      }
      expect(appLocationForLink(Uri.parse(forYouSeeAllLink)), '/discover/events');
    });

    test('an event with no slug opens by its id; no venue, no place', () {
      final home = _home();
      final pick = pickFromHome(
          DiscoverHome(where: home.where, popular: home.popular),
          const ForYouAsk(api: _api),
          _now);
      final open = pick.events.firstWhere((e) => e.id == 109).toJson();
      expect(open['link'], 'https://myotherapp.in/events/109');
      expect(open.containsKey('place'), isFalse);
      expect(open.containsKey('club'), isFalse);
    });

    test('nothing read yet: empty, read at the epoch, so the widget asks', () {
      final json = ForYouSnapshot.unread(const ForYouAsk(api: _api)).toJson();
      expect(json['state'], 'empty');
      expect(json['items'], isEmpty);
      expect(json['fetched_at'], 0);
      expect(json.containsKey('header'), isFalse);
    });
  });

  group('ForYouWidgetSync', () {
    test('the same list is written once; again after half an hour', () async {
      final store = MemoryWidgetStore();
      var now = _now;
      final sync = ForYouWidgetSync(store, now: () => now);
      const ask = ForYouAsk(api: _api, topics: [3]);

      await sync.show(_home(), ask);
      await sync.show(_home(), ask);
      expect(store.writes, hasLength(1));

      now = now.add(const Duration(minutes: 31));
      await sync.show(_home(), ask);
      expect(store.writes, hasLength(2));
      expect(store.last['fetched_at'], now.millisecondsSinceEpoch);
    });

    test('a change is written at once', () async {
      final store = MemoryWidgetStore();
      final sync = ForYouWidgetSync(store, now: () => _now);
      await sync.show(_home(), const ForYouAsk(api: _api, topics: [3]));
      await sync.show(_home(), const ForYouAsk(api: _api));
      expect(store.writes, hasLength(2));
      expect(store.last['header'], 'This week near you');
    });

    test('signing out: asked again without the topics; the place stays',
        () async {
      final store = MemoryWidgetStore();
      final place = DiscoverPlaceState(
          place: const DiscoverWhere(
              city: 'Kochi', lat: 9.93, lng: 76.27, source: WhereSource.picked));
      await showSignedOutOnForYouWidget(store, api: _api, place: place);
      expect(store.last['state'], 'empty');
      expect(store.last['items'], isEmpty);
      expect(store.last['fetched_at'], 0);
      expect(store.last['ask'],
          {'api': _api, 'topics': [], 'city': 'Kochi', 'lat': 9.93, 'lng': 76.27});
    });

    test('topicsOf: the interests\' topics, by id', () {
      expect(topicsOf(null), isEmpty);
      expect(
          topicsOf(const UserProfile(id: 'u', fullName: 'A', email: 'a@b.c',
              interests: [
                Interest(id: 1, name: 'Flutter', categoryId: 3),
                Interest(id: 2, name: 'Old'),
              ])),
          [3]);
    });
  });

  group('ForYouWidgetSyncScope', () {
    late MemoryWidgetStore store;
    late ProviderContainer container;
    late int homeReads;

    Future<void> run(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(WidgetTester tester,
        {bool placed = true, List<int> topics = const [3]}) async {
      store = MemoryWidgetStore()..placed = placed;
      homeReads = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          forYouStoreProvider.overrideWithValue(store),
          forYouWidgetSyncProvider
              .overrideWith((ref) => ForYouWidgetSync(store, now: () => _now)),
          forYouApiBaseProvider.overrideWithValue(_api),
          discoverHomeProvider.overrideWith((ref) {
            homeReads++;
            return Stream.value(_home());
          }),
          discoverPlaceStoreProvider.overrideWithValue(MemoryDiscoverPlaceStore(
              const DiscoverWhere(
                  city: 'Kochi',
                  lat: 9.931,
                  lng: 76.267,
                  source: WhereSource.picked))),
          profileRepositoryProvider.overrideWithValue(_Profiles(topics)),
          isAuthenticatedProvider.overrideWith((ref) => ref.watch(_signedIn)),
        ],
        child: const MaterialApp(
          home: ForYouWidgetSyncScope(child: Text('the tabs')),
        ),
      ));
      container =
          ProviderScope.containerOf(tester.element(find.text('the tabs')));
      await run(tester);
    }

    testWidgets('no widget placed: nothing is read or written for it',
        (tester) async {
      await pump(tester, placed: false);
      expect(store.writes, isEmpty);
      expect(homeReads, 0);
    });

    testWidgets(
        'a widget placed: the front page is listed for the person\'s topics '
        'and place', (tester) async {
      await pump(tester);
      expect(homeReads, 1);
      expect(store.last['header'], 'For you');
      expect(store.last['ask'],
          {'api': _api, 'topics': [3], 'city': 'Kochi', 'lat': 9.93, 'lng': 76.27});
      expect([for (final i in store.last['items']) i['id']].first, 101);
      // Nothing of the account.
      expect(store.writes.last, isNot(contains('asha@example.com')));
      expect(store.writes.last, isNot(contains('Asha')));
    });

    testWidgets('signed out: the same page, without the topics',
        (tester) async {
      await pump(tester);
      container.read(_signedIn.notifier).state = false;
      await run(tester);
      expect(store.last['ask']['topics'], isEmpty);
      expect(store.last['header'], 'This week near you');
      container.read(_signedIn.notifier).state = true;
      await run(tester);
    });

    testWidgets('back to the front: the widget is drawn again',
        (tester) async {
      await pump(tester);
      final before = store.redraws;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await run(tester);
      expect(store.redraws, before + 1);
    });

    testWidgets('a widget placed while the app was away is followed on return',
        (tester) async {
      await pump(tester, placed: false);
      expect(store.writes, isEmpty);
      store.placed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await run(tester);
      expect(store.writes, hasLength(1));
      expect(store.last['state'], 'events');
    });
  });
}
