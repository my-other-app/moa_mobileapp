import 'dart:io';
import 'dart:typed_data';

import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/home_widget/data/event_day_platform.dart';
import 'package:finnet/features/home_widget/data/for_you_store.dart';
import 'package:finnet/features/home_widget/data/networking_store.dart';
import 'package:finnet/features/home_widget/data/next_up_store.dart';
import 'package:finnet/features/home_widget/data/widget_photos.dart';
import 'package:finnet/features/home_widget/data/widget_store.dart';
import 'package:finnet/features/home_widget/presentation/for_you_widget_sync.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/auth_fakes.dart';
import '../../features/home_widget/widget_fakes.dart';

class _FakeImageCache extends Fake implements BaseCacheManager {
  int emptied = 0;

  @override
  Future<void> emptyCache() async => emptied++;
}

/// A home-screen widget's storage, in memory.
class _WidgetStore implements WidgetStore {
  final writes = <String>[];

  @override
  Future<void> write(String json) async => writes.add(json);

  @override
  Future<void> redraw() async {}

  @override
  Future<bool> isPlaced() async => false;
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

    final nextUp = _WidgetStore();
    final networking = _WidgetStore();
    // "Recently met" with photos turned on, and one kept.
    final photos = MemoryPhotoStore()..on = true;
    await photos.save('networking_photo_5', 'f', Uint8List(3));
    // The events widget, listed for the person's topics; and their event's
    // card up on the lock screen, with the switch on.
    final forYou = _WidgetStore();
    final phone = FakeEventDayPlatform()..up = 7;
    final eventDay = MemoryEventDayStore()
      ..saved = const EventDayChoices(shown: {7: 1795869000000});
    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
      sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
      nextUpStoreProvider.overrideWithValue(nextUp),
      networkingStoreProvider.overrideWithValue(networking),
      widgetPhotoStoreProvider.overrideWithValue(photos),
      forYouStoreProvider.overrideWithValue(forYou),
      forYouApiBaseProvider
          .overrideWithValue('https://api.myotherapp.in/api/v1'),
      eventDayPlatformProvider.overrideWithValue(phone),
      eventDayStoreProvider.overrideWithValue(eventDay),
    ]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);

    await container.read(authStateProvider.notifier).logout();

    // The home-screen widgets: the signed-out face, nothing of the person.
    expect(nextUp.writes.single, contains('"state":"signed_out"'));
    expect(networking.writes.single,
        allOf(contains('"state":"signed_out"'), isNot(contains('/p/'))));
    // Its photos, and the switch: the next person starts with initials.
    expect(photos.files, isEmpty);
    expect(photos.on, isFalse);
    // The events widget: asked again without the person's topics.
    expect(forYou.writes.single,
        allOf(contains('"topics":[]'), contains('"fetched_at":0')));
    // The event-day card: down, the event forgotten; the switch stays on.
    expect(phone.up, isNull);
    expect(eventDay.saved.shown, isEmpty);
    expect(eventDay.saved.on, isTrue);

    expect(storage.values, isEmpty,
        reason: 'tokens, saved answers and saved tickets, all gone');
    expect(shared.values, isEmpty);
    expect(await pdf.exists(), isFalse);
    expect(privateImages.emptied, 1);
    expect(publicImages.emptied, 0, reason: 'posters can stay');
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
  });
}
