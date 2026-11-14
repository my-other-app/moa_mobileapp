import 'dart:io';

import 'package:finnet/core/auth/jwt_claims.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import 'volunteer_fakes.dart';

/// Door scans saved with no signal outlive the session: a sign-out, a
/// session the server ended, a sign-in. They go when their own account is
/// back, and never under another one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late MemoryStorage storage;
  late FakeGateApi api;
  final previousDocuments = DocumentCache.instance;
  final previousApi = ApiCache.instance;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('door_session');
    storage = MemoryStorage();
    api = FakeGateApi();
    FlutterSecureStorage.setMockInitialValues({});
    // What else a sign-out empties, here instead of the phone's.
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

  /// The app's providers as a session has them, with the phone's queue in
  /// [dir] and the server [api]. Everything kept about the person is
  /// really cleared ([sessionCachesProvider] as it is).
  ProviderContainer session() {
    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
      sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
      signOutServerTimeoutProvider
          .overrideWithValue(const Duration(milliseconds: 50)),
      gateApiProvider.overrideWithValue(api),
      scanQueueStoreProvider.overrideWith((ref) => FileScanQueueStore(
            root: () async => dir,
            ownerId: ref.watch(
                authStateProvider.select((s) => userIdOf(s.accessToken))),
          )),
    ]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> saveFor(int owner, String ref) =>
      FileScanQueueStore(root: () async => dir, ownerId: owner).add(QueuedScan(
          eventId: 7,
          code: 'MOA-AAAAA-$ref',
          clientRef: 'ref-$ref-xxxxxxxx',
          scannedAt: DateTime.utc(2026, 11, 28, 9)));

  Future<int> savedFor(int owner) =>
      FileScanQueueStore(root: () async => dir, ownerId: owner).count();

  test('signing out keeps them', () async {
    storage.values.addAll(
        {'access_token': tokenWithSid('s-1', userId: 41), 'refresh_token': 'r'});
    api.batchError = noSignal('/scan-batch');
    final container = session();
    await settle();
    await saveFor(41, 'AAAAA');

    await container.read(authStateProvider.notifier).logout();

    expect(await savedFor(41), 1);
  });

  test('a session the server ended keeps them too', () async {
    storage.values.addAll(
        {'access_token': tokenWithSid('s-1', userId: 41), 'refresh_token': 'r'});
    api.batchError = noSignal('/scan-batch');
    final container = session();
    await settle();
    await saveFor(41, 'AAAAA');

    SessionEvents.reportRevoked(SessionEndReason.expired);
    await settle();

    expect(container.read(authStateProvider).isAuthenticated, isFalse);
    expect(await savedFor(41), 1);
  });

  test('signing in again sends them, as that account', () async {
    await saveFor(41, 'AAAAA');
    final container = session();
    await settle();

    await container.read(authStateProvider.notifier).setAuthenticated(
        accessToken: tokenWithSid('s-2', userId: 41), refreshToken: 'r');
    await settle();

    expect(api.batches.single.single.clientRef, 'ref-AAAAA-xxxxxxxx');
    expect(await savedFor(41), 0);
  });

  test('another account signing in neither sends nor sees them', () async {
    await saveFor(41, 'AAAAA');
    final container = session();
    await settle();

    await container.read(authStateProvider.notifier).setAuthenticated(
        accessToken: tokenWithSid('s-3', userId: 52), refreshToken: 'r');
    await settle();

    expect(api.batches, isEmpty);
    expect(await container.read(scanQueueStoreProvider).count(), 0);
    expect(await savedFor(41), 1);
  });

  test('a session restored at start-up sends them', () async {
    await saveFor(41, 'AAAAA');
    storage.values.addAll(
        {'access_token': tokenWithSid('s-1', userId: 41), 'refresh_token': 'r'});

    session();
    await settle();

    expect(api.batches, hasLength(1));
    expect(await savedFor(41), 0);
  });
}

class _FakeImageCache extends Fake implements BaseCacheManager {
  @override
  Future<void> emptyCache() async {}
}
