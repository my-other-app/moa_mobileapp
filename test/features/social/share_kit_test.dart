import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/social/data/share_kit_api.dart';
import 'package:finnet/features/social/domain/share_kit.dart';
import 'package:finnet/features/social/presentation/pages/share_kit_pages.dart';
import 'package:finnet/features/social/presentation/social_routes.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

/// `GET /social/share-kit/{event_id}` as the contract has it.
Map<String, dynamic> _kit() => {
      'event': {
        'id': 7,
        'name': 'DevFest Kochi',
        'date': '2030-12-01T10:00:00+05:30',
        'slug': 'devfest-kochi',
      },
      'platforms': [
        {
          'platform': 'instagram',
          'text': 'DevFest is here! Link in bio.',
          'image_url': 'https://media.myotherapp.in/p/ig.jpg',
          'link': 'https://myotherapp.in/events/devfest-kochi?utm_source=instagram',
        },
        {
          'platform': 'whatsapp',
          'text': '*DevFest Kochi*\nRegister: https://myotherapp.in/e/abc',
          'image_url': 'https://media.myotherapp.in/p/story.jpg',
          'link': 'https://myotherapp.in/e/abc',
        },
        {
          'platform': 'linkedin',
          'text': 'Join us at DevFest Kochi',
          'image_url': 'https://media.myotherapp.in/p/li.jpg',
          'link': 'https://myotherapp.in/events/devfest-kochi?utm_source=linkedin',
        },
        {
          'platform': 'x',
          'text': 'DevFest Kochi https://myotherapp.in/events/devfest-kochi?utm_source=x',
          'image_url': null,
          'link': 'https://myotherapp.in/events/devfest-kochi?utm_source=x',
        },
        {'platform': 'facebook', 'text': ''},
      ],
    };

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Shared {
  final List<({String? text, String? imagePath})> shares = [];
  final List<String> posters = [];
  String? clipboard;
}

void main() {
  group('reading a kit', () {
    test('each platform, with its words, poster and link', () {
      final kit = ShareKit.fromJson(_kit(), eventId: 7);
      expect(kit.event.name, 'DevFest Kochi');
      expect(kit.event.slug, 'devfest-kochi');
      expect(kit.posts.map((p) => p.platform),
          ['instagram', 'whatsapp', 'linkedin', 'x']);
      expect(kit.posts.map((p) => p.label),
          ['Instagram', 'WhatsApp', 'LinkedIn', 'X']);
      expect(kit.posts.map((p) => p.copiesCaptionFirst),
          [true, true, false, false]);
      expect(kit.posts[0].pasteInto, 'Instagram');
      expect(kit.posts[1].pasteInto, 'WhatsApp');
      expect(kit.posts[3].imageUrl, isNull);
      expect(captionFirstPlatform('whatsapp_status'), isTrue);
      expect(captionFirstPlatform('instagram_story'), isTrue);
      expect(shareKitPlatformLabel('whatsapp_status'), 'WhatsApp Status');
    });

    test('the words carry the link, once', () {
      final kit = ShareKit.fromJson(_kit(), eventId: 7);
      expect(shareKitText(kit.posts[2]),
          'Join us at DevFest Kochi\n\nhttps://myotherapp.in/events/devfest-kochi?utm_source=linkedin');
      expect(shareKitText(kit.posts[3]), kit.posts[3].text);
    });

    test('the list of kits: a bare list or items, rows or events', () {
      // As the server lists them: {id, name, date, slug, image_url}.
      final listed = ShareKitEvent.listFrom([
        {
          'id': 7,
          'name': 'DevFest',
          'date': '2030-12-01T10:00:00+05:30',
          'slug': 'devfest',
          'image_url': 'https://media.myotherapp.in/p/og.jpg',
        }
      ]);
      expect(listed.single.poster, 'https://media.myotherapp.in/p/og.jpg');
      expect(listed.single.date, isNotNull);
      final kits = ShareKitEvent.listFrom([
        {'event': {'id': 7, 'name': 'DevFest'}, 'club': {'name': 'GDG Kochi'}},
        {'event_id': 8, 'event_name': 'Hack Night', 'club_name': 'Tinkerhub'},
        {'name': 'No id'},
      ]);
      expect(kits.map((k) => k.id), [7, 8]);
      expect(kits.first.clubName, 'GDG Kochi');
      expect(kits.last.name, 'Hack Night');
      expect(ShareKitEvent.listFrom({'items': [{'id': 9, 'name': 'X'}]}).single.id,
          9);
      expect(ShareKitEvent.listFrom('nonsense'), isEmpty);
    });

    test('a share_kit push opens the kit', () {
      expect(shareKitRoute(7), '/profile/share-kits/7');
    });
  });

  group('the share_kit push', () {
    test('opens the event\'s kit; the list without an event', () {
      expect(
          NotificationService.routeFor(
              const {'type': 'share_kit', 'event_id': '7'}),
          '/profile/share-kits/7');
      expect(NotificationService.routeFor(const {'type': 'share_kit'}),
          '/profile/share-kits');
    });

    test('its inbox line opens the same kit', () {
      final line = NotificationModel.fromJson({
        'id': 'n-1',
        'user_id': 1,
        'title': 'DevFest Kochi is live — share it',
        'description': '',
        'type': 'share_kit',
        'status': 'unread',
        'event': {'id': 7, 'name': 'DevFest Kochi'},
        'data': {'event_id': '7'},
        'created_at': '2026-11-11T10:00:00Z',
      });
      expect(line.route, '/profile/share-kits/7');
      expect(line.iconEmoji, '📣');
    });

    test('signed out, it asks for sign-in first', () {
      expect(needsAccount('/profile/share-kits/7'), isTrue);
      expect(needsAccount('/profile/share-kits'), isTrue);
    });

    test("the app's router has both screens", () {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(
            const AuthState(accessToken: 'token', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      String? nameOf(String path) =>
          router.configuration.findMatch(Uri.parse(path)).last.route.name;
      expect(nameOf('/profile/share-kits/7'), 'shareKit');
      expect(nameOf('/profile/share-kits'), 'shareKits');
    });
  });

  group('whether there are kits', () {
    test('signed out: none, and nothing is asked', () async {
      final api = useFakeApi();
      final container = ProviderContainer(overrides: [
        isAuthenticatedProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(shareKitsProvider.future), isEmpty);
      expect(api.requests, isEmpty);
    });

    test('a server without share kits (404): none, so no entry', () async {
      useFakeApi();
      final container = ProviderContainer(overrides: [
        isAuthenticatedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(shareKitsProvider.future), isEmpty);
    });

    test('the kits there are', () async {
      final api = useFakeApi();
      api.on('GET', '/social/share-kits', [
        {'event': {'id': 7, 'name': 'DevFest'}}
      ]);
      final container = ProviderContainer(overrides: [
        isAuthenticatedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(shareKitsProvider.future), hasLength(1));
    });

    test('a kit the person may not see (403) or none (404) is null', () async {
      final api = useFakeApi();
      api.on('GET', '/social/share-kit/8', {'message': 'Not on the team'},
          status: 403);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(shareKitProvider(7).future), isNull);
      expect(await container.read(shareKitProvider(8).future), isNull);
    });
  });

  group('the kit screen', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    Future<_Shared> pump(WidgetTester tester, {bool posterFails = false}) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final shared = _Shared();
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          shared.clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      final rootKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: rootKey,
        initialLocation: shareKitRoute(7),
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, __) => const Scaffold(body: Text('profile')),
            routes: socialRoutes(rootKey),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(APIService.instance.dio),
          posterFileProvider.overrideWithValue((url) async {
            shared.posters.add(url);
            if (posterFails) throw Exception('offline');
            return '/tmp/${url.split('/').last}';
          }),
          shareKitSharerProvider.overrideWithValue(
              ({text, imagePath, origin}) async =>
                  shared.shares.add((text: text, imagePath: imagePath))),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return shared;
    }

    Future<void> tapShare(WidgetTester tester, String platform) async {
      final button = find.byKey(ValueKey('share-kit-share-$platform'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('each platform, its words and a Share button', (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      await pump(tester);

      expect(find.text('DevFest Kochi'), findsOneWidget);
      for (final label in ['Instagram', 'WhatsApp', 'LinkedIn', 'X']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('DevFest is here! Link in bio.'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-kit-share-facebook')),
          findsNothing, reason: 'a platform without words is left out');
    });

    testWidgets('Instagram: the caption is copied first, then the poster '
        'alone is shared', (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      final shared = await pump(tester);

      await tapShare(tester, 'instagram');

      expect(shared.clipboard, 'DevFest is here! Link in bio.');
      expect(find.text('Caption copied — paste it in Instagram'),
          findsOneWidget);
      expect(shared.shares.single.text, isNull);
      expect(shared.shares.single.imagePath, '/tmp/ig.jpg');
    });

    testWidgets('WhatsApp: the caption copied for Status, and the poster '
        'with its words for a chat', (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      final shared = await pump(tester);

      await tapShare(tester, 'whatsapp');

      expect(shared.clipboard,
          '*DevFest Kochi*\nRegister: https://myotherapp.in/e/abc');
      expect(find.text('Caption copied — paste it in WhatsApp'),
          findsOneWidget);
      expect(shared.shares.single.imagePath, '/tmp/story.jpg');
      expect(shared.shares.single.text,
          '*DevFest Kochi*\nRegister: https://myotherapp.in/e/abc');
    });

    testWidgets('LinkedIn: the poster with its words and link, nothing copied',
        (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      final shared = await pump(tester);

      await tapShare(tester, 'linkedin');

      expect(shared.clipboard, isNull);
      expect(shared.shares.single.imagePath, '/tmp/li.jpg');
      expect(shared.shares.single.text,
          contains('https://myotherapp.in/events/devfest-kochi?utm_source=linkedin'));
    });

    testWidgets('no poster: the words alone', (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      final shared = await pump(tester);

      await tapShare(tester, 'x');

      expect(shared.posters, isEmpty);
      expect(shared.shares.single.imagePath, isNull);
      expect(shared.shares.single.text, startsWith('DevFest Kochi'));
    });

    testWidgets('Instagram without its poster shares nothing and says so',
        (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      final shared = await pump(tester, posterFails: true);

      await tapShare(tester, 'instagram');

      expect(shared.shares, isEmpty);
      expect(shared.clipboard, 'DevFest is here! Link in bio.');
      expect(find.textContaining("Couldn't get the poster"), findsOneWidget);
    });

    testWidgets('Copy text copies the words with the link', (tester) async {
      api.on('GET', '/social/share-kit/7', _kit());
      final shared = await pump(tester);

      final copy = find.byKey(const ValueKey('share-kit-copy-linkedin'));
      await tester.ensureVisible(copy);
      await tester.pump();
      await tester.tap(copy);
      await tester.pump();

      expect(shared.clipboard, contains('Join us at DevFest Kochi'));
      expect(shared.clipboard, contains('utm_source=linkedin'));
    });

    testWidgets('not on the team, or no kit: said so', (tester) async {
      await pump(tester);
      expect(find.byKey(ShareKitPage.missingKey), findsOneWidget);
    });
  });
}
