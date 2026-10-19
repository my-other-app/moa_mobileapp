// Signed-in screens offline, over the app's own Dio stack (`buildAppDio`):
// what the owner found on the phone -- "If there is no internet, even the
// settings page is not getting loaded" -- and the screens that showed a
// spinner or an error over what they had.
//
// The simulator runs signed out against production, so the signed-in
// journeys are here. The saved answers are memory stores (a widget test's
// clock is fake; the file store is covered in offline_stack_test.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/app/session_scope.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/core/services/analytics_service.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/pages/notifications/notifications_page.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';
import 'package:finnet/features/profile/presentation/pages/settings_page.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_fakes.dart';

const _base = 'https://api.test/api/v1';

/// Answers by path; refuses every connection while [offline]; holds every
/// answer while [gate] is open (a signal too weak to answer).
class _Server implements HttpClientAdapter {
  final routes = <String, Object?>{};
  bool offline = false;
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final held = gate;
    if (held != null) await held.future;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
        error: const SocketException('Failed host lookup'),
      );
    }
    final path = options.uri.path;
    if (!routes.containsKey(path)) {
      return ResponseBody.fromString('{"message":"Not found"}', 404,
          headers: {
            'content-type': ['application/json'],
          });
    }
    return ResponseBody.fromString(jsonEncode(routes[path]), 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryChoices implements PrivacyChoicesStore {
  PrivacyChoices kept = PrivacyChoices.defaults;

  @override
  Future<PrivacyChoices> read() async => kept;

  @override
  Future<void> write(PrivacyChoices choices) async => kept = choices;
}

class _NoCollection implements CollectionControl {
  @override
  Future<void> applyChoices(PrivacyChoices choices) async {}
}

const _profile = {
  'id': 42,
  'full_name': 'Aarav Menon',
  'email': 'aarav@example.com',
  'interests': [],
};

void main() {
  late _Server server;
  late ApiCache cache;
  late NetworkStatus status;
  late Dio dio;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(
        {'access_token': 'a', 'refresh_token': 'r'});
    server = _Server();
    cache = ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
    ApiCache.instance = cache;
    status = NetworkStatus(probe: () async => false);
    dio = buildAppDio(status: status, baseUrl: _base)
      ..httpClientAdapter = server;
  });

  tearDown(() => ApiCache.instance = null);

  Future<void> save(String path, Object data,
      {Map<String, dynamic>? query, CacheScope scope = CacheScope.personal}) {
    return cache.write(
      ApiCache.keyForRequest(dio, path, query: query),
      scope,
      CacheEntry(data: data, savedAt: DateTime.now()),
    );
  }

  /// [home] under the app's providers, signed in, over [dio].
  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(
        path: '/profile/settings',
        builder: (_, __) => const SettingsPage(),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        apiCacheProvider.overrideWithValue(cache),
        isAuthenticatedProvider.overrideWithValue(true),
        privacyChoicesStoreProvider.overrideWithValue(_MemoryChoices()),
        collectionControlProvider.overrideWithValue(_NoCollection()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
  }

  /// Let requests fail and retry (the retry waits under a second).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Take the tree down, then stop the status's probe timer.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    server.gate?.complete();
    status.reportOnline();
    await tester.pump(const Duration(seconds: 1));
  }

  group('Profile and Settings', () {
    testWidgets(
        'on a signal too weak to answer, the saved profile and the menu show '
        'at once, and Settings opens', (tester) async {
      await save('/user/profile/me', _profile);
      server.gate = Completer<void>();

      await pump(tester, const ProfilePage());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ShimmerProfileCard), findsNothing,
          reason: 'the saved profile is there: no shimmer while it refreshes');
      expect(find.text('Aarav Menon'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);

      await finish(tester);
    });

    testWidgets(
        'offline with no profile saved, the menu stays -- Settings and Log '
        'Out are still there', (tester) async {
      server.offline = true;

      await pump(tester, const ProfilePage());
      await settle(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing,
          reason: 'not a full-page error');

      await tester.tap(find.text('Settings'));
      await tester.pump();
      await settle(tester);
      expect(find.byType(SettingsPage), findsOneWidget);

      await finish(tester);
    });

    testWidgets('Settings itself opens offline', (tester) async {
      server.offline = true;
      await save('/user/profile/me', _profile);

      await pump(tester, const SettingsPage());
      await settle(tester);

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Blocked Users'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);

      await finish(tester);
    });
  });

  group('a cold start with a stored session, offline', () {
    testWidgets('stays signed in, clears nothing, and shows the saved profile',
        (tester) async {
      server.offline = true;
      await save('/user/profile/me', _profile);
      final storage = MemoryStorage({'access_token': 'a', 'refresh_token': 'r'});
      final caches = FakeSessionCaches();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(SessionScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storage),
          pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
          sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
          sessionCachesProvider.overrideWithValue(caches),
          dioProvider.overrideWithValue(dio),
          apiCacheProvider.overrideWithValue(cache),
          privacyChoicesStoreProvider.overrideWithValue(_MemoryChoices()),
          collectionControlProvider.overrideWithValue(_NoCollection()),
        ],
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            final auth = ref.watch(authStateProvider);
            if (!auth.isInitialized) return const SizedBox();
            return auth.isAuthenticated
                ? const ProfilePage()
                : const Text('signed out');
          }),
        ),
      ));
      await settle(tester);

      expect(find.text('signed out'), findsNothing);
      expect(find.text('Aarav Menon'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(caches.cleared, 0, reason: 'a network failure clears nothing');
      expect(storage.values['access_token'], 'a');
      expect(storage.values['refresh_token'], 'r');
      expect(status.isOffline, isTrue);

      await finish(tester);
    });
  });

  group('Notifications', () {
    testWidgets('the saved list shows offline, with no error', (tester) async {
      await save('/notifications/fetch-list', {
        'items': [
          {
            'id': 'n1',
            'title': 'Hack Night starts soon',
            'description': 'Doors at 6',
            'status': 'read',
            'created_at': DateTime.now().toIso8601String(),
          }
        ]
      }, query: {
        'limit': 20,
        'offset': 0
      });
      server.offline = true;

      await pump(tester, const NotificationsNewPage());
      await settle(tester);

      expect(find.text('Hack Night starts soon'), findsOneWidget);
      expect(find.textContaining('Error'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await finish(tester);
    });
  });
}
