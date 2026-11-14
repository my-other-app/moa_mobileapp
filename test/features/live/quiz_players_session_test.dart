import 'dart:io';

import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';

/// A second person signing in on the phone must not join a quiz as the
/// first one's player.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late MemoryLiveStore live;
  final previousDocuments = DocumentCache.instance;
  final previousApi = ApiCache.instance;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('quiz_session');
    live = MemoryLiveStore();
    FlutterSecureStorage.setMockInitialValues({});
    ApiCache.instance =
        ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
    DocumentCache.instance =
        DocumentCache(root: () async => Directory('${dir.path}/documents'));
    AppImageCaches.debugOverride(
        public: _FakeImageCache(), private: _FakeImageCache());
  });
  tearDown(() async {
    DocumentCache.instance = previousDocuments;
    ApiCache.instance = previousApi;
    AppImageCaches.debugOverride();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<ProviderContainer> session({bool signedIn = true}) async {
    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(MemoryStorage({
        if (signedIn) 'access_token': tokenWithSid('s-1'),
        if (signedIn) 'refresh_token': 'r',
      })),
      pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
      sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
      unsentWorkProvider.overrideWithValue(FakeUnsentWork()),
      signOutServerTimeoutProvider
          .overrideWithValue(const Duration(milliseconds: 50)),
      liveIdentityProvider.overrideWithValue(LiveIdentity(live)),
    ]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return container;
  }

  Future<void> joinQuiz(ProviderContainer container) async {
    final identity = container.read(liveIdentityProvider);
    await identity.installKey();
    await identity.savePlayer(
        const QuizPlayer(eventId: 7, playerKey: 'k1', name: 'Asha'));
  }

  test('signing out forgets the quiz players and the install key', () async {
    final container = await session();
    await joinQuiz(container);

    await container.read(authStateProvider.notifier).logout();

    expect(live.values, isEmpty);
  });

  test('a quiz joined before signing in is still theirs after', () async {
    final container = await session(signedIn: false);
    await joinQuiz(container);

    await container
        .read(authStateProvider.notifier)
        .setAuthenticated(accessToken: tokenWithSid('s-2'), refreshToken: 'r');

    expect(live.values.keys,
        containsAll([LiveIdentity.installKeyName, 'live_player_7']));
  });
}

class _FakeImageCache extends Fake implements BaseCacheManager {
  @override
  Future<void> emptyCache() async {}
}
