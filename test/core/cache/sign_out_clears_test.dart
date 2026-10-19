import 'dart:io';

import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/auth_fakes.dart';

class _FakeImageCache extends Fake implements BaseCacheManager {
  int emptied = 0;

  @override
  Future<void> emptyCache() async => emptied++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late MemoryStorage storage;
  late MemoryCacheStore shared;
  late ApiCache api;
  late _FakeImageCache publicImages;
  late _FakeImageCache privateImages;
  late ApiCache previousApi;
  late DocumentCache previousDocuments;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sign_out_test');
    storage = MemoryStorage({
      'access_token': tokenWithSid('s-1'),
      'refresh_token': 'r',
    });
    shared = MemoryCacheStore();
    api = ApiCache(shared: shared, personal: SecureCacheStore(storage));
    previousApi = ApiCache.instance;
    previousDocuments = DocumentCache.instance;
    ApiCache.instance = api;
    DocumentCache.instance =
        DocumentCache(root: () async => Directory('${dir.path}/documents'));
    publicImages = _FakeImageCache();
    privateImages = _FakeImageCache();
    AppImageCaches.debugOverride(public: publicImages, private: privateImages);
  });

  tearDown(() async {
    ApiCache.instance = previousApi;
    DocumentCache.instance = previousDocuments;
    AppImageCaches.debugOverride();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('signing out clears every cache of the person, and leaves the posters',
      () async {
    // What a session leaves on the phone.
    final now = DateTime.now();
    await api.write('GET /api/v1/events/list?is_registered=true',
        CacheScope.personal, CacheEntry(data: {'items': []}, savedAt: now));
    await api.write('GET /api/v1/user/profile/me', CacheScope.personal,
        CacheEntry(data: {'full_name': 'Ana'}, savedAt: now));
    await api.write('GET /api/v1/events/for-you', CacheScope.shared,
        CacheEntry(data: {'items': []}, savedAt: now));
    await SavedTicketsLocalDataSource(storage).write([
      const SavedTicket(code: 'MOA-1', eventId: 1, eventName: 'Hack'),
    ]);
    final pdf = File('${dir.path}/documents/ticket_MOA-1.pdf');
    await pdf.create(recursive: true);
    await pdf.writeAsString('PDF');

    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
      sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
    ]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);

    await container.read(authStateProvider.notifier).logout();

    expect(storage.values, isEmpty,
        reason: 'tokens, saved answers and saved tickets, all gone');
    expect(shared.values, isEmpty);
    expect(await pdf.exists(), isFalse);
    expect(privateImages.emptied, 1);
    expect(publicImages.emptied, 0, reason: 'posters can stay');
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
  });
}
