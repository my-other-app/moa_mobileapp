import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/events/presentation/pages/networking_page.dart';
import 'package:finnet/features/network/data/network_files.dart';
import 'package:finnet/features/network/data/save_queue.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/domain/profile.dart' show Audience;
import 'package:finnet/features/network/presentation/network_routes.dart';
import 'package:finnet/features/network/presentation/pages/code_save_page.dart';
import 'package:finnet/features/network/presentation/pages/edit_public_profile_page.dart';
import 'package:finnet/features/network/presentation/pages/my_qr_page.dart';
import 'package:finnet/features/network/presentation/pages/network_page.dart';
import 'package:finnet/features/network/presentation/pages/network_person_page.dart';
import 'package:finnet/features/network/presentation/pages/public_profile_page.dart';
import 'package:finnet/features/network/presentation/pages/save_person_scanner_page.dart';
import 'package:finnet/features/network/presentation/pages/stranger_preview_page.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/widgets/link_sheet.dart';
import 'package:finnet/features/network/presentation/widgets/save_outcome_card.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../events/events_fakes.dart';
import '../threads/moderation_fakes.dart';
import 'network_fixtures.dart';

class _Light implements ScreenLight {
  int raised = 0;
  int restored = 0;

  @override
  Future<void> raise() async => raised++;

  @override
  Future<void> restore() async => restored++;
}

class _Profiles implements ProfileRepository {
  @override
  Future<UserProfile?> getSavedProfile() async => null;

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(
      const UserProfile(id: '1', fullName: 'Asha Menon', email: 'a@b.test'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// No signal: every request fails before an answer.
class _NoSignal implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketException('No route to host'),
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _body(RequestOptions r) =>
    r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const {};

class _Harness {
  _Harness(this.router, {MemoryPendingSaveStore? store})
      : store = store ?? MemoryPendingSaveStore();
  final GoRouter router;
  final shared = <String>[];
  final opened = <Uri>[];
  final light = _Light();
  final MemoryPendingSaveStore store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<_Harness> _pump(
  WidgetTester tester,
  String start, {
  bool signedIn = true,
  int? atEvent,
  MemoryPendingSaveStore? store,
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rootKey = GlobalKey<NavigatorState>();
  final router =
      GoRouter(navigatorKey: rootKey, initialLocation: start, routes: [
    ...profileLinkRoutes,
    networkTabRoute(rootKey),
    GoRoute(
      path: '/profile',
      builder: (_, __) => const Scaffold(body: Text('the profile tab')),
      routes: myNetworkProfileRoutes(rootKey),
    ),
    GoRoute(
      path: '/events/:ref',
      builder: (_, __) => const Scaffold(body: Text('the event')),
    ),
  ]);
  addTearDown(router.dispose);
  final h = _Harness(router, store: store);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(signedIn),
      linkLauncherProvider.overrideWithValue((uri) async {
        h.opened.add(uri);
        return true;
      }),
      textFileSharerProvider.overrideWithValue(({
        required fileName,
        required text,
        required mimeType,
        subject,
        origin,
      }) async =>
          h.shared.add(fileName)),
      profileLinkSharerProvider.overrideWithValue((text) async {}),
      pendingSaveStoreProvider.overrideWithValue(h.store),
      screenLightProvider.overrideWithValue(h.light),
      atEventIdProvider.overrideWith((ref) => atEvent),
      profileRepositoryProvider.overrideWithValue(_Profiles()),
      moderationRepositoryProvider
          .overrideWithValue(FakeModerationRepository()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return h;
}

void main() {
  group('a public profile', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    testWidgets('what the viewer may see, and Save', (tester) async {
      api
        ..on('GET', '/profiles/ananya', publicProfileJson())
        ..on('POST', '/network', saveResultJson());
      final h = await _pump(tester, '/u/ananya', atEvent: 9);

      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.text("Flutter dev · CET '27"), findsOneWidget);
      expect(find.text('CET Trivandrum · Kochi'), findsOneWidget);
      expect(find.text('Club app'), findsOneWidget);
      expect(find.text('“State in Flutter” at Hack Night'), findsOneWidget);

      await tester.tap(find.byKey(
          const ValueKey('profile-link-github-https://github.com/ananya')));
      await tester.pump();
      expect(h.opened.single.toString(), 'https://github.com/ananya');

      await tester.tap(find.byKey(PublicProfilePage.saveKey));
      await _settle(tester);
      expect(_body(api.sent('POST', '/network').single),
          {'handle': 'ananya', 'method': 'link', 'event_id': 9});
      expect(find.byKey(PublicProfilePage.savedKey), findsOneWidget);
      expect(find.text('In your network'), findsOneWidget);
    });

    testWidgets('signed out, Save asks for an account and sends nothing',
        (tester) async {
      api.on('GET', '/profiles/ananya', publicProfileJson());
      await _pump(tester, '/u/ananya', signedIn: false);

      await tester.tap(find.byKey(PublicProfilePage.saveKey));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPromptSheet), findsOneWidget);
      expect(api.sent('POST', '/network'), isEmpty);
    });

    testWidgets('?save=1 puts the Save offer first', (tester) async {
      api.on('GET', '/profiles/ananya', publicProfileJson());
      await _pump(tester, '/u/ananya?save=1');

      final offer = find.byKey(const ValueKey('profile-save-offer'));
      expect(offer, findsOneWidget);
      expect(tester.getTopLeft(find.byKey(PublicProfilePage.saveKey)).dy,
          lessThan(tester.getTopLeft(find.text('Ananya Iyer')).dy));
    });

    testWidgets('private, to a stranger: only the basics', (tester) async {
      api.on('GET', '/profiles/ananya', {
        'handle': 'ananya',
        'full_name': 'Ananya Iyer',
        'headline': 'Flutter dev',
        'private': true,
      });
      await _pump(tester, '/u/ananya');
      expect(find.byKey(const ValueKey('profile-locked')), findsOneWidget);
    });

    testWidgets('my own: Edit, never Save', (tester) async {
      api.on('GET', '/profiles/asha', myProfileJson());
      await _pump(tester, '/u/asha');
      expect(find.byKey(PublicProfilePage.editKey), findsOneWidget);
      expect(find.byKey(PublicProfilePage.saveKey), findsNothing);
    });

    testWidgets('unknown, hidden or blocked: said plainly', (tester) async {
      await _pump(tester, '/u/nobody');
      expect(find.byKey(PublicProfilePage.missingKey), findsOneWidget);
    });
  });

  group("a personal QR's link", () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    testWidgets('opening it saves nobody: the profile, and Save on a tap',
        (tester) async {
      api
        ..on('GET', '/profiles/by-code/abcdefghjk',
            {'handle': 'ananya', 'profile': publicProfileJson()})
        ..on('POST', '/network', saveResultJson());
      await _pump(tester, '/p/abcdefghjk', atEvent: 9);

      // Open, settled, and still nothing sent.
      await tester.pumpAndSettle();
      expect(api.sent('POST', '/network'), isEmpty);
      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.text('Save Ananya'), findsOneWidget);

      await tester.tap(find.byKey(CodeSavePage.saveKey));
      await _settle(tester);
      // A link is not a scan: saved as `link`, at the event if any.
      expect(_body(api.sent('POST', '/network').single),
          {'code': 'abcdefghjk', 'method': 'link', 'event_id': 9});
      expect(find.byKey(SaveOutcomeCard.savedKey), findsOneWidget);
      expect(find.byKey(SaveOutcomeCard.noteKey), findsOneWidget);
    });

    testWidgets('already saved: In your network, and no Save', (tester) async {
      api.on('GET', '/profiles/by-code/abcdefghjk', {
        'handle': 'ananya',
        'profile': publicProfileJson(relation: {
          'saved_by_me': true,
          'saved_me': false,
          'mutual': false,
          'network_id': 5,
        }),
      });
      await _pump(tester, '/p/abcdefghjk');
      expect(find.byKey(CodeSavePage.savedKey), findsOneWidget);
      expect(find.byKey(CodeSavePage.saveKey), findsNothing);
      expect(api.sent('POST', '/network'), isEmpty);
    });

    testWidgets('my own code says so, and offers My QR', (tester) async {
      api.on('GET', '/profiles/by-code/abcdefghjk',
          {'handle': 'asha', 'profile': myProfileJson()});
      await _pump(tester, '/p/abcdefghjk');
      expect(find.byKey(CodeSavePage.ownKey), findsOneWidget);
      expect(find.text('Show my QR'), findsOneWidget);
      expect(find.byKey(CodeSavePage.saveKey), findsNothing);
      expect(api.sent('POST', '/network'), isEmpty);
    });

    testWidgets('signed out: the profile, and Save asks for an account',
        (tester) async {
      api.on('GET', '/profiles/by-code/abcdefghjk',
          {'handle': 'ananya', 'profile': publicProfileJson()});
      await _pump(tester, '/p/abcdefghjk', signedIn: false);

      expect(find.text('Ananya Iyer'), findsOneWidget);
      await tester.tap(find.byKey(CodeSavePage.saveKey));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPromptSheet), findsOneWidget);
      expect(api.sent('POST', '/network'), isEmpty);
    });

    testWidgets('a replaced code is no longer active', (tester) async {
      api.on('GET', '/profiles/by-code/oldoldoldo',
          {'message': 'Gone', 'error_code': profileCodeInactiveCode},
          status: 410);
      await _pump(tester, '/p/oldoldoldo', signedIn: false);
      expect(find.byKey(CodeSavePage.problemKey), findsOneWidget);
      expect(find.textContaining('no longer active'), findsOneWidget);
    });
  });

  group('the Network tab', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    testWidgets('grouped by event, who saved you, a person, export',
        (tester) async {
      api
        ..on(
            'GET',
            '/network',
            networkListJson([
              networkPersonJson(tags: ['flutter'])
            ]))
        ..on('GET', '/network/saved-me', {
          'items': [
            {
              'person':
                  personBriefJson(userId: 50, handle: 'riya', name: 'Riya')
            },
            {'person': personBriefJson(userId: 51, handle: 'sam', name: 'Sam')},
          ],
          'total': 2,
        })
        ..on('GET', '/network/export', 'BEGIN:VCARD\nEND:VCARD');
      final h = await _pump(tester, '/network');

      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.text('DevFest · 28 Nov · 1 person'), findsOneWidget);
      expect(find.textContaining('Met DevFest'), findsOneWidget);
      expect(find.text('2 people saved you. Save them back?'), findsOneWidget);

      await tester.tap(find.byKey(NetworkPage.exportKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export to contacts (vCard)'));
      await _settle(tester);
      expect(h.shared.single, 'my-network.vcf');

      await tester.tap(find.byKey(const ValueKey('network-person-5')));
      await tester.pumpAndSettle();
      expect(find.byType(NetworkPersonPage), findsOneWidget);
    });

    testWidgets('mutual only asks the server for it', (tester) async {
      api.on('GET', '/network', networkListJson([networkPersonJson()]));
      await _pump(tester, '/network');
      await tester.tap(find.byKey(NetworkPage.mutualKey));
      await _settle(tester);
      expect(api.sent('GET', '/network').last.queryParameters['mutual'], true);
    });

    testWidgets("the recap's link: who was met at the event", (tester) async {
      api.on('GET', '/network', networkListJson([networkPersonJson()]));
      await _pump(tester, '/network?event=9');
      expect(api.sent('GET', '/network').single.queryParameters['event_id'], 9);
      expect(find.byKey(NetworkPage.recapKey), findsOneWidget);
      expect(find.text('You met 1 person at DevFest'), findsOneWidget);
    });

    testWidgets('nobody yet: how to start', (tester) async {
      api.on('GET', '/network', networkListJson(const []));
      await _pump(tester, '/network');
      expect(find.byKey(NetworkPage.emptyKey), findsOneWidget);
    });

    testWidgets('saves waiting for a signal are shown, and sent with Try now',
        (tester) async {
      final store = MemoryPendingSaveStore();
      await store.add(PendingSave(
          clientRef: 'a',
          code: 'abcdefghjk',
          method: MetHow.qr,
          eventId: 9,
          metAt: DateTime.utc(2026, 11, 28)));
      APIService.instance.dio.httpClientAdapter = _NoSignal();
      await _pump(tester, '/network', store: store);
      expect(find.byKey(NetworkPage.pendingKey), findsOneWidget);
      expect(find.text('1 save is waiting for a signal'), findsOneWidget);

      // The signal is back.
      final online = useFakeApi()
        ..on('GET', '/network', networkListJson(const []))
        ..on('POST', '/network', saveResultJson());
      await tester.tap(find.text('Try now'));
      await _settle(tester);
      expect(_body(online.sent('POST', '/network').single), {
        'code': 'abcdefghjk',
        'method': 'qr',
        'event_id': 9,
        'met_at': '2026-11-28T00:00:00.000Z',
      });
      expect(store.saved, isEmpty);
      expect(find.byKey(NetworkPage.pendingKey), findsNothing);
    });

    testWidgets('a save waiting when the tab opens is sent then',
        (tester) async {
      final store = MemoryPendingSaveStore();
      await store.add(PendingSave(
          clientRef: 'a',
          handle: 'ananya',
          method: MetHow.discovery,
          metAt: DateTime.utc(2026, 11, 28)));
      api
        ..on('GET', '/network', networkListJson(const []))
        ..on('POST', '/network', saveResultJson());
      await _pump(tester, '/network', store: store);
      expect(api.sent('POST', '/network'), hasLength(1));
      expect(store.saved, isEmpty);
    });
  });

  group('one person', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    testWidgets('where you met, your note, and Remove', (tester) async {
      api
        ..on('GET', '/network/5',
            networkPersonJson(note: 'Talk about Riverpod', tags: ['flutter']))
        ..on('DELETE', '/network/5', null, status: 204);
      await _pump(tester, '/network/5');

      expect(find.text('Talk about Riverpod'), findsOneWidget);
      expect(find.text('DevFest'), findsOneWidget);
      expect(find.textContaining('Scanned their QR'), findsOneWidget);

      await tester.tap(find.byKey(NetworkPersonPage.menuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from my network'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('network-remove-confirm')));
      await _settle(tester);
      expect(api.sent('DELETE', '/network/5'), hasLength(1));
    });

    testWidgets('a note and tags, from the sheet', (tester) async {
      api
        ..on('GET', '/network/5', networkPersonJson())
        ..on('PATCH', '/network/5', networkPersonJson(note: 'Hiring'));
      await _pump(tester, '/network/5');

      await tester.tap(find.byKey(NetworkPersonPage.noteKey));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('network-note-field')), 'Hiring');
      await tester.enterText(
          find.byKey(const ValueKey('network-tag-field')), 'design');
      await tester.tap(find.byKey(const ValueKey('network-note-save')));
      await _settle(tester);
      expect(_body(api.sent('PATCH', '/network/5').single), {
        'note': 'Hiring',
        'tags': ['design']
      });
    });
  });

  group('who saved you', () {
    testWidgets('Save back, with the event they saved you at', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/network/saved-me', {
          'items': [
            {'person': personBriefJson(), 'event': devFest()},
          ],
          'total': 1,
        })
        ..on('POST', '/network', saveResultJson(mutual: true));
      await _pump(tester, '/network/saved-me');

      expect(find.text('Saved you at DevFest'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-back-ananya')));
      await _settle(tester);
      expect(_body(api.sent('POST', '/network').single),
          {'handle': 'ananya', 'method': 'link', 'event_id': 9});
      expect(find.text('Saved'), findsOneWidget);
    });
  });

  group('the scanner', () {
    Future<_Harness> pumpScanner(WidgetTester tester, {int? eventId}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = _Harness(GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      ]));
      addTearDown(h.router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          pendingSaveStoreProvider.overrideWithValue(h.store),
        ],
        child: MaterialApp(
          home: SavePersonScannerPage(
            eventId: eventId,
            camera: (context, onCode) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (key, code) in const [
                  ('scan-ticket', 'MOA-7K3QF-X9PWM'),
                  ('scan-person', 'https://myotherapp.in/p/abcdefghjk'),
                  ('scan-other', 'https://example.com'),
                ])
                  TextButton(
                    key: ValueKey(key),
                    onPressed: () => onCode(code),
                    child: Text(key),
                  ),
              ],
            ),
          ),
        ),
      ));
      await _settle(tester);
      return h;
    }

    testWidgets("a ticket is a ticket: nothing is read or sent",
        (tester) async {
      final api = useFakeApi();
      await pumpScanner(tester);
      await tester.tap(find.byKey(const ValueKey('scan-ticket')));
      await _settle(tester);
      expect(find.byKey(SaveOutcomeCard.refusedKey), findsOneWidget);
      expect(find.text(SavePersonScannerPage.ticketMessage), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('a personal QR saves them, at the event', (tester) async {
      final api = useFakeApi()..on('POST', '/network', saveResultJson());
      await pumpScanner(tester, eventId: 9);
      await tester.tap(find.byKey(const ValueKey('scan-person')));
      await _settle(tester);
      expect(_body(api.sent('POST', '/network').single),
          {'code': 'abcdefghjk', 'method': 'qr', 'event_id': 9});
      expect(find.byKey(SaveOutcomeCard.savedKey), findsOneWidget);
    });

    testWidgets('with no signal it is kept, and says so', (tester) async {
      useFakeApi();
      APIService.instance.dio.httpClientAdapter = _NoSignal();
      final h = await pumpScanner(tester, eventId: 9);
      await tester.tap(find.byKey(const ValueKey('scan-person')));
      await _settle(tester);
      expect(find.byKey(SaveOutcomeCard.laterKey), findsOneWidget);
      expect(find.text('1 save waiting for a signal'), findsOneWidget);
      expect(h.store.saved.single.eventId, 9);
    });

    testWidgets('anything else is not a personal QR', (tester) async {
      useFakeApi();
      await pumpScanner(tester);
      await tester.tap(find.byKey(const ValueKey('scan-other')));
      await _settle(tester);
      expect(find.text(SavePersonScannerPage.otherMessage), findsOneWidget);
    });
  });

  group('My QR', () {
    testWidgets('the code, the name under it, the screen turned up',
        (tester) async {
      final api = useFakeApi()
        ..on('GET', '/me/qr', {
          'code': 'abcdefghjk',
          'url': 'https://myotherapp.in/p/abcdefghjk',
        })
        ..on('GET', '/me/profile', myProfileJson())
        ..on('POST', '/me/qr/replace', {
          'code': 'mnpqrstuvw',
          'url': 'https://myotherapp.in/p/mnpqrstuvw',
        });
      final h = await _pump(tester, '/profile/qr');

      final qr = tester.widget<QrImageView>(find.byKey(MyQrPage.qrKey));
      expect(qr, isNotNull);
      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.text("Flutter dev · CET '27"), findsOneWidget);
      expect(find.text('myotherapp.in/u/asha'), findsOneWidget);
      expect(h.light.raised, 1);

      await tester.tap(find.byKey(MyQrPage.replaceKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace code'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-qr-replace-confirm')));
      await _settle(tester);
      expect(api.sent('POST', '/me/qr/replace'), hasLength(1));
      expect(api.sent('GET', '/me/qr'), hasLength(2));

      h.router.go('/profile');
      await tester.pumpAndSettle();
      expect(h.light.restored, 1);
    });

    testWidgets('scanning switched off: said, with the way back on',
        (tester) async {
      useFakeApi()
        ..on('GET', '/me/qr', {
          'code': 'abcdefghjk',
          'url': 'https://myotherapp.in/p/abcdefghjk',
        })
        ..on('GET', '/me/profile',
            myProfileJson(settings: {'scanning_enabled': false}));
      await _pump(tester, '/profile/qr');
      expect(find.byKey(MyQrPage.scanningOffKey), findsOneWidget);
    });
  });

  group('editing the public profile', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    testWidgets('the fields, filled; a change is saved as just that change',
        (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('PATCH', '/me/profile', myProfileJson());
      await _pump(tester, '/profile/public');

      expect(find.byKey(EditPublicProfilePage.completenessKey), findsOneWidget);
      expect(find.text('Add a link and a project.'), findsOneWidget);
      final handle =
          tester.widget<TextField>(find.byKey(EditPublicProfilePage.handleKey));
      expect(handle.controller!.text, 'asha');

      await tester.enterText(
          find.byKey(EditPublicProfilePage.headlineKey), 'Designer at CET');
      await tester.pump();
      await tester.tap(find.byKey(EditPublicProfilePage.saveAboutKey));
      await _settle(tester);
      expect(_body(api.sent('PATCH', '/me/profile').single),
          {'headline': 'Designer at CET'});
    });

    testWidgets('a handle goes as the server keeps it: no @, lower case',
        (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('PATCH', '/me/profile', myProfileJson(handle: 'asha.m'));
      await _pump(tester, '/profile/public');
      await tester.enterText(
          find.byKey(EditPublicProfilePage.handleKey), '@Asha.M');
      await tester.pump();
      await tester.tap(find.byKey(EditPublicProfilePage.saveAboutKey));
      await _settle(tester);
      expect(
          _body(api.sent('PATCH', '/me/profile').single), {'handle': 'asha.m'});
    });

    testWidgets("a handle that can't be used is said before sending",
        (tester) async {
      api.on('GET', '/me/profile', myProfileJson());
      await _pump(tester, '/profile/public');
      await tester.enterText(
          find.byKey(EditPublicProfilePage.handleKey), 'admin');
      await tester.pump();
      await tester.tap(find.byKey(EditPublicProfilePage.saveAboutKey));
      await _settle(tester);
      expect(find.text('That one is reserved.'), findsOneWidget);
      expect(api.sent('PATCH', '/me/profile'), isEmpty);
    });

    testWidgets("a taken handle: the server's word, under the field",
        (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('PATCH', '/me/profile',
            {'message': 'Taken', 'error_code': handleTakenCode},
            status: 409);
      await _pump(tester, '/profile/public');
      await tester.enterText(
          find.byKey(EditPublicProfilePage.handleKey), 'ananya');
      await tester.pump();
      await tester.tap(find.byKey(EditPublicProfilePage.saveAboutKey));
      await _settle(tester);
      expect(find.text('Someone already has that handle.'), findsOneWidget);
    });

    testWidgets('a pasted link picks its type, and the list is saved',
        (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on(
            'PUT',
            '/me/profile/links',
            myProfileJson(links: [
              {'type': 'github', 'url': 'https://github.com/asha'},
            ]));
      await _pump(tester, '/profile/public');

      await tester.tap(find.byKey(EditPublicProfilePage.addLinkKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(LinkSheet.urlKey), 'github.com/asha');
      await tester.pump();
      await tester.tap(find.byKey(LinkSheet.doneKey));
      await _settle(tester);
      expect(_body(api.sent('PUT', '/me/profile/links').single), {
        'links': [
          {'type': 'github', 'url': 'https://github.com/asha'},
        ],
      });
      expect(find.text('LINKS · 1/10'), findsOneWidget);
    });

    testWidgets('a switch is saved on its own', (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('PATCH', '/me/profile', myProfileJson());
      await _pump(tester, '/profile/public');
      await tester.tap(find.byKey(const ValueKey('switch-notify_saves')));
      await _settle(tester);
      expect(_body(api.sent('PATCH', '/me/profile').single),
          {'notify_saves': false});
    });

    testWidgets('who sees a part: the whole visibility goes', (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('PATCH', '/me/profile', myProfileJson());
      await _pump(tester, '/profile/public');
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('visibility-links')),
          matching: find.byType(DropdownButton<Audience>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only me').last);
      await _settle(tester);
      expect(_body(api.sent('PATCH', '/me/profile').single), {
        'visibility': {
          'links': 'me',
          'projects': 'met',
          'achievements': 'everyone',
          'interests': 'everyone',
          'org': 'everyone',
        },
      });
    });

    testWidgets('the preview asks as a stranger', (tester) async {
      api
        ..on('GET', '/me/profile', myProfileJson())
        ..on('GET', '/profiles/asha',
            publicProfileJson(handle: 'asha', name: 'Asha Menon'));
      await _pump(tester, '/profile/public/preview');
      expect(find.byKey(StrangerPreviewPage.bannerKey), findsOneWidget);
      expect(
          api.sent('GET', '/profiles/asha').single.extra['skipAuth'], isTrue);
    });
  });

  group('People Like You', () {
    testWidgets('Save on a card saves them from discovery, at the event',
        (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/7/networking', {
          'event_id': 7,
          'event_name': 'Hack Night',
          'visible': true,
          'attendees': [
            {
              'user_id': 41,
              'name': 'Ravi Kumar',
              'handle': 'ravi',
              'saved': false,
              'shared_interests': [
                {'id': 1, 'name': 'AI'},
              ],
              'match_count': 1,
            },
            {
              'user_id': 42,
              'name': 'Neha',
              'handle': 'neha',
              'saved': true,
              'match_count': 0,
            },
            {'user_id': 43, 'name': 'Old server', 'match_count': 0},
          ],
        })
        ..on('POST', '/network', saveResultJson());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          moderationRepositoryProvider
              .overrideWithValue(FakeModerationRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          pendingSaveStoreProvider.overrideWithValue(MemoryPendingSaveStore()),
        ],
        child: const MaterialApp(
          home: NetworkingPage(eventId: 7, eventName: 'Hack Night'),
        ),
      ));
      await _settle(tester);

      expect(find.byKey(const ValueKey('person-saved-42')), findsOneWidget);
      expect(find.byKey(const ValueKey('person-save-43')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('person-save-41')));
      await _settle(tester);
      expect(_body(api.sent('POST', '/network').single),
          {'handle': 'ravi', 'method': 'discovery', 'event_id': 7});
      expect(find.byKey(const ValueKey('person-saved-41')), findsOneWidget);
    });
  });
}
