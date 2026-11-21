import 'dart:io';

import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The icon's shortcuts (docs/HOME_WIDGETS.md): Scan, My QR, Network, My
/// tickets. They are native -- the iPhone's quick actions in Info.plist,
/// Android's dynamic shortcuts from res/values/app_shortcuts.xml -- and each
/// opens a website address the way a widget's tap does, which the router
/// reads as the app's own page. These hold both lists to the same four
/// links, and each link to the page it should open, with sign-in first.

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

/// What each shortcut must open, in the order the menus show them.
const _expected = [
  (id: 'scan', title: 'Scan', location: savePersonScanLocation),
  (id: 'my-qr', title: 'My QR', location: myQrLocation),
  (id: 'network', title: 'Network', location: networkLocation),
  (id: 'my-tickets', title: 'My tickets', location: '/events'),
];

/// The iPhone's quick actions: (type, title, symbol, link), in order.
List<({String type, String title, String symbol, String link})> _iosItems() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final list = RegExp(
          r'<key>UIApplicationShortcutItems</key>\s*<array>(.*?)\n\t</array>',
          dotAll: true)
      .firstMatch(plist);
  expect(list, isNotNull, reason: 'UIApplicationShortcutItems');
  String value(String item, String key) =>
      RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
          .firstMatch(item)![1]!;
  return [
    for (final item in RegExp(r'\t\t<dict>(.*?)\n\t\t</dict>', dotAll: true)
        .allMatches(list![1]!))
      (
        type: value(item[1]!, 'UIApplicationShortcutItemType'),
        title: value(item[1]!, 'UIApplicationShortcutItemTitle'),
        symbol: value(item[1]!, 'UIApplicationShortcutItemIconSymbolName'),
        link: value(item[1]!, 'link'),
      ),
  ];
}

/// Android's strings, by name.
Map<String, String> _androidStrings() {
  final xml = File('android/app/src/main/res/values/app_shortcuts.xml')
      .readAsStringSync();
  return {
    for (final m in RegExp(r'<string name="([^"]+)"[^>]*>([^<]*)</string>')
        .allMatches(xml))
      m[1]!: m[2]!.replaceAll(r"\'", "'"),
  };
}

/// Android's shortcuts in the order AppShortcuts.kt publishes them: the
/// string-name stem of each.
List<String> _androidOrder() {
  final kotlin =
      File('android/app/src/main/kotlin/app/myotherapp/com/AppShortcuts.kt')
          .readAsStringSync();
  return [
    for (final m
        in RegExp(r'R\.string\.shortcut_(\w+)_link').allMatches(kotlin))
      m[1]!,
  ];
}

void main() {
  test(
      'the iPhone has the four quick actions, in order, with the app\'s '
      'symbols', () {
    final items = _iosItems();
    expect(
        [for (final i in items) i.title], [for (final e in _expected) e.title]);
    expect([for (final i in items) i.type],
        [for (final e in _expected) 'app.myotherapp.in.${e.id}']);
    // SF Symbols there since iOS 14, the app's minimum.
    expect([for (final i in items) i.symbol],
        ['qrcode.viewfinder', 'qrcode', 'person.2', 'ticket']);
  });

  test('Android has the same four, with the same links, in the same order', () {
    final strings = _androidStrings();
    final order = _androidOrder();
    expect(order, ['scan', 'my_qr', 'network', 'tickets']);
    expect([for (final stem in order) strings['shortcut_${stem}_link']],
        [for (final i in _iosItems()) i.link]);
    for (final stem in order) {
      final short = strings['shortcut_${stem}_short']!;
      final long = strings['shortcut_${stem}_long']!;
      // The launcher's limits: 10 and 25 characters.
      expect(short.length, lessThanOrEqualTo(10), reason: short);
      expect(long.length, lessThanOrEqualTo(25), reason: long);
    }
    expect([for (final stem in order) strings['shortcut_${stem}_short']],
        [for (final e in _expected) e.title]);
  });

  group('each link opens its page', () {
    ProviderContainer containerWith(AuthState state) {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(state)),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('the website address reads as the app\'s page', () {
      final router = containerWith(_signedIn).read(routerProvider);
      final items = _iosItems();
      for (var i = 0; i < items.length; i++) {
        final link = Uri.parse(items[i].link);
        // The only addresses AppDelegate's AppShortcuts.link accepts.
        expect(link.scheme, 'https');
        expect(link.host, 'myotherapp.in');
        final location = appLocationForLink(link);
        expect(location, _expected[i].location, reason: items[i].title);
        final match = router.configuration.findMatch(Uri.parse(location!));
        expect(match.isEmpty, isFalse, reason: location);
      }
    });

    test('My QR is the full-screen code, not a person called "qr"', () {
      final router = containerWith(_signedIn).read(routerProvider);
      String? nameOf(String location) =>
          router.configuration.findMatch(Uri.parse(location)).last.route.name;
      expect(nameOf(myQrLocation), 'myQr');
      expect(nameOf(savePersonScanLocation), 'savePersonScan');
      expect(nameOf(networkLocation), AppRoutes.network);
    });

    test('signed out, each asks to sign in and comes back to it', () {
      for (final e in _expected) {
        expect(needsAccount(e.location), isTrue, reason: e.location);
        expect(
            authRedirect(_signedOut, e.location), signInLocation(e.location));
        // Opened from the icon while the app starts: held, then sign-in.
        expect(authRedirect(_signedOut, signInPath, launchLink: e.location),
            signInLocation(e.location));
        expect(authRedirect(_signedIn, e.location), isNull);
      }
    });
  });
}
