import 'dart:convert';

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/home_widget/data/networking_store.dart';
import 'package:finnet/features/home_widget/data/next_up_store.dart';
import 'package:finnet/features/home_widget/data/widget_store.dart';
import 'package:finnet/features/home_widget/domain/networking.dart';
import 'package:finnet/features/home_widget/presentation/networking_widget_sync.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

import '../events/events_fakes.dart';
import '../network/network_fixtures.dart';

/// The Networking widget's storage, kept in memory.
class _Store implements WidgetStore {
  final writes = <String>[];
  int redraws = 0;
  bool placed = false;

  Map<String, dynamic> get last =>
      jsonDecode(writes.last) as Map<String, dynamic>;

  @override
  Future<void> write(String json) async => writes.add(json);

  @override
  Future<void> redraw() async => redraws++;

  @override
  Future<bool> isPlaced() async => placed;
}

class _Profiles extends FakeProfileRepository {
  int asked = 0;

  @override
  Future<Result<UserProfile>> getMyProfile() {
    asked++;
    return super.getMyProfile();
  }
}

const _link = 'https://myotherapp.in/p/abcdefghjk';
const _newLink = 'https://myotherapp.in/p/mnpqrstuvw';

/// Everything the widget's JSON may hold (docs/HOME_WIDGETS.md).
const _allowed = {
  'v',
  'state',
  'name',
  'profile_link',
  'network',
  'met',
  'no_note',
  'links',
};

final _signedIn = StateProvider<bool>((ref) => true);

void main() {
  group('NetworkingSnapshot', () {
    test('signed out: nothing about anyone, only where a tap goes', () {
      final json = NetworkingSnapshot.from(
        signedIn: false,
        qrLink: _link,
        name: 'Asha Menon',
        networkCount: 12,
      ).toJson();

      expect(json, {
        'v': 1,
        'state': 'signed_out',
        'links': networkingLinks,
      });
    });

    test('signed in with the code: the link it encodes, the name, the count',
        () {
      final json = NetworkingSnapshot.from(
        signedIn: true,
        qrLink: _link,
        name: '  Asha \n Menon ',
        networkCount: 12,
      ).toJson();

      expect(json['state'], 'ready');
      expect(json['profile_link'], _link);
      expect(json['name'], 'Asha Menon');
      expect(json['network'], 12);
      expect(json.keys.toSet().difference(_allowed), isEmpty);
    });

    test('no code read yet: the calm placeholder, with what else is known', () {
      final json = NetworkingSnapshot.from(
        signedIn: true,
        name: 'Asha Menon',
      ).toJson();

      expect(json['state'], 'no_qr');
      expect(json.containsKey('profile_link'), isFalse);
      expect(json.containsKey('network'), isFalse);
      expect(json['name'], 'Asha Menon');
    });

    test('only a personal QR\'s link is ever drawn as the code', () {
      for (final other in [
        'https://myotherapp.in/tickets/MOA-ABC-123',
        'https://myotherapp.in/u/asha',
        'http://myotherapp.in/p/abcdefghjk',
        'https://elsewhere.example/p/abcdefghjk',
        'https://myotherapp.in/p/short',
        'abcdefghjk',
        '',
      ]) {
        final json =
            NetworkingSnapshot.from(signedIn: true, qrLink: other).toJson();
        expect(json['state'], 'no_qr', reason: other);
        expect(json.containsKey('profile_link'), isFalse, reason: other);
      }
      expect(isProfileQrLink(_link), isTrue);
    });

    test('a count below nought is left out; a very long name is cut', () {
      final json = NetworkingSnapshot.from(
        signedIn: true,
        name: 'A' * 200,
        networkCount: -1,
      ).toJson();
      expect(json.containsKey('network'), isFalse);
      expect((json['name'] as String).length, 80);
    });

    test('each tap opens its page, signing in first', () {
      expect(networkingLinks.keys, ['qr', 'scan', 'network']);
      final expected = {
        'qr': myQrLocation,
        'scan': savePersonScanLocation,
        'network': networkLocation,
      };
      for (final MapEntry(:key, :value) in networkingLinks.entries) {
        final location = appLocationForLink(Uri.parse(value));
        expect(location, expected[key], reason: key);
        expect(needsAccount(location!), isTrue, reason: key);
      }
    });
  });

  group('NetworkingWidgetSync', () {
    test('writes what the widget shows, and the same thing once', () async {
      final store = _Store();
      final sync = NetworkingWidgetSync(store);

      await sync.signedOut();
      await sync.signedOut();
      await sync.show(NetworkingSnapshot.from(signedIn: true, qrLink: _link));

      expect(store.writes, hasLength(2));
      expect(jsonDecode(store.writes.first)['state'], 'signed_out');
      expect(store.last['profile_link'], _link);
    });

    test('signing out puts the signed-out face on the widget', () async {
      final store = _Store();
      await showSignedOutOnNetworkingWidget(store);
      expect(store.last['state'], 'signed_out');
      expect(store.last.keys.toSet(), {'v', 'state', 'links'});
    });
  });

  group('which widget is on the home screen', () {
    final networking = HomeWidgetNetworkingStore(supported: false);
    final nextUp = HomeWidgetNextUpStore(supported: false);

    test('iOS: by its kind', () {
      final placed = HomeWidgetInfo(iOSKind: 'NetworkingWidget');
      expect(networking.isThisKind(placed), isTrue);
      expect(nextUp.isThisKind(placed), isFalse);
    });

    test('Android: by its provider, named in full or from the package', () {
      for (final name in [
        'app.myotherapp.com.widget.NetworkingWidgetProvider',
        '.widget.NetworkingWidgetProvider',
      ]) {
        final placed = HomeWidgetInfo(androidClassName: name);
        expect(networking.isThisKind(placed), isTrue, reason: name);
        expect(nextUp.isThisKind(placed), isFalse, reason: name);
      }
      expect(networking.isThisKind(HomeWidgetInfo(androidClassName: 'Other')),
          isFalse);
    });
  });

  group('NetworkingWidgetSyncScope', () {
    late _Store store;
    late _Profiles profiles;
    late RouteAdapter api;
    late ProviderContainer container;

    /// Runs the test's clock on: the fake API answers on it, and a provider
    /// invalidated is read again at a frame.
    Future<void> run(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Lets [work] finish.
    Future<void> settle(WidgetTester tester, Future<Object?> work) async {
      await run(tester);
      await work;
      await tester.pump();
    }

    /// Reads a page of the network as a screen does: listened to while read.
    Future<void> readNetwork(WidgetTester tester, NetworkQuery query) async {
      final page = container.listen(networkListProvider(query), (_, __) {});
      await run(tester);
      page.close();
    }

    Future<void> pump(WidgetTester tester,
        {bool placed = false, List<int> totals = const [5]}) async {
      store = _Store()..placed = placed;
      profiles = _Profiles();
      api = useFakeApi()
        ..on('GET', '/me/qr', {'code': 'abcdefghjk', 'url': _link})
        ..on('GET', '/me/profile', myProfileJson());
      // Each read of the network answers the next total; the last stays.
      for (final total in totals) {
        api.on('GET', '/network', {'items': [], 'total': total});
      }
      await tester.pumpWidget(ProviderScope(
        overrides: [
          networkingStoreProvider.overrideWithValue(store),
          profileRepositoryProvider.overrideWithValue(profiles),
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

    testWidgets(
        'with no widget placed, it writes what is known and asks the server '
        'nothing', (tester) async {
      await pump(tester);

      expect(store.last['state'], 'no_qr');
      expect(api.sent('GET', '/me/qr'), isEmpty);
      expect(api.sent('GET', '/network'), isEmpty);
      expect(api.sent('GET', '/me/profile'), isEmpty);
      expect(profiles.asked, 0);
    });

    testWidgets('My QR reading the code puts it on the widget', (tester) async {
      await pump(tester);

      await settle(tester, container.read(myQrProvider.future));

      expect(store.last['state'], 'ready');
      expect(store.last['profile_link'], _link);
    });

    testWidgets('a replaced code replaces the old one on the widget at once',
        (tester) async {
      await pump(tester);
      await settle(tester, container.read(myQrProvider.future));

      container.read(lastKnownQrProvider.notifier).state =
          const MyQr(code: 'mnpqrstuvw', url: _newLink);
      await tester.pump();

      expect(store.last['profile_link'], _newLink);
      expect(store.writes.last, isNot(contains('abcdefghjk')));
    });

    testWidgets(
        'the network\'s size follows a read of the whole network, not a '
        'search', (tester) async {
      // The search answers 1 person: not the network's size.
      await pump(tester, totals: [5, 1]);

      await readNetwork(tester, const NetworkQuery());
      expect(store.last['network'], 5);

      await readNetwork(tester, const NetworkQuery(q: 'ananya'));
      expect(api.sent('GET', '/network'), hasLength(2));
      expect(store.last['network'], 5);
    });

    testWidgets('the name follows the profile, and never the email or phone',
        (tester) async {
      await pump(tester);

      await settle(tester, container.read(myProfileProvider.notifier).load());
      expect(store.last['name'], 'Asha Menon');

      // The account's profile, once read: its email and phone stay out.
      container.read(profileProvider);
      await run(tester);
      for (final json in store.writes) {
        expect(json, isNot(contains('asha@example.com')));
        expect(json, isNot(contains('9876543210')));
      }
    });

    testWidgets('signing out leaves nothing about the person', (tester) async {
      await pump(tester);
      await settle(tester, container.read(myQrProvider.future));
      await readNetwork(tester, const NetworkQuery());
      expect(store.last['state'], 'ready');

      container.read(_signedIn.notifier).state = false;
      await tester.pump();

      expect(store.last.keys.toSet(), {'v', 'state', 'links'});
      expect(store.last['state'], 'signed_out');
    });

    testWidgets(
        'a widget on a home screen: the code, the name and the count are read '
        'for it', (tester) async {
      await pump(tester, placed: true);

      expect(api.sent('GET', '/me/qr'), hasLength(1));
      // One read of the network answers the count and "Recently met": its
      // first page, last met first.
      final counts = api.sent('GET', '/network');
      expect(counts, hasLength(1));
      expect(counts.single.queryParameters['sort'], 'met');
      expect(counts.single.queryParameters['page'], 1);
      expect(counts.single.queryParameters['page_size'], 50);
      expect(profiles.asked, 1);

      expect(store.last['state'], 'ready');
      expect(store.last['profile_link'], _link);
      expect(store.last['network'], 5);
      expect(store.last['name'], 'Asha Menon');
      expect(store.last.keys.toSet().difference(_allowed), isEmpty);
    });

    testWidgets(
        'placed: a save (which reads the network again) moves the count on',
        (tester) async {
      await pump(tester, placed: true, totals: [5, 6]);
      expect(store.last['network'], 5);

      container.invalidate(networkListProvider);
      await run(tester);

      expect(store.last['network'], 6);
    });

    testWidgets('back to the front: the widget is drawn again', (tester) async {
      await pump(tester);
      final before = store.redraws;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(store.redraws, before + 1);
    });
  });
}
