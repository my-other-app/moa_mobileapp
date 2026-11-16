import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ios_keychain_fake.dart';

void main() {
  group('where the sign-in tokens are kept', () {
    const store = SecureStorageService.platformStorage;

    test('Android: EncryptedSharedPreferences, under the Keystore', () {
      expect(store.aOptions.toMap()['encryptedSharedPreferences'], 'true');
    });

    test(
        'iOS: the Keychain, readable once the phone is first unlocked, on '
        'this phone only, and not synced to other devices', () {
      final ios = store.iOptions.toMap();
      expect(ios['accessibility'], 'first_unlock_this_device');
      expect(ios['synchronizable'], 'false');
    });

    test('the older builds\' store differs only in its iOS accessibility', () {
      const legacy = SecureStorageService.legacyPlatformStorage;
      expect(legacy.iOptions.toMap(),
          {...store.iOptions.toMap(), 'accessibility': 'first_unlock'});
      expect(legacy.aOptions.toMap(), store.aOptions.toMap());
    });

    test('the service uses that store unless a test hands in another',
        () async {
      FlutterSecureStorage.setMockInitialValues({});

      await SecureStorageService()
          .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

      // Read straight from the encrypted store, not through the service.
      expect(await store.readAll(), {
        'access_token': 'access-1',
        'refresh_token': 'refresh-1',
      });
    });
  });

  group('the tokens', () {
    late SecureStorageService storage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = SecureStorageService();
    });

    test('nothing is stored before a sign-in', () async {
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('are saved together and read back', () async {
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(await storage.getAccessToken(), 'a');
      expect(await storage.getRefreshToken(), 'r');
    });

    test('a refreshed access token replaces the old one alone', () async {
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

      await storage.saveAccessToken('a2');

      expect(await storage.getAccessToken(), 'a2');
      expect(await storage.getRefreshToken(), 'r');
    });

    test('signing out clears both and leaves the rest of the store', () async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'a',
        'refresh_token': 'r',
        'privacy_choices': '{"analytics":false}',
      });
      storage = SecureStorageService();

      await storage.clearTokens();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(
          await storage.readAll(), {'privacy_choices': '{"analytics":false}'});
    });

    test('clearAll empties the store', () async {
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
      await storage.write(key: 'other', value: 'x');

      await storage.clearAll();

      expect(await storage.readAll(), isEmpty);
      expect(await storage.containsKey(key: 'access_token'), isFalse);
    });
  });
  group('on an iPhone, entries an older build wrote', () {
    const older = KeychainAccessibility.first_unlock;
    const thisDevice = KeychainAccessibility.first_unlock_this_device;
    late FakeIosKeychain keychain;
    late SecureStorageService storage;

    setUp(() {
      keychain = FakeIosKeychain()
        ..put('access_token', 'a', older)
        ..put('refresh_token', 'r', older)
        ..put('saved:/user/profile', '{}', older);
      storage = SecureStorageService(
          storage: keychain.at(thisDevice), legacy: keychain.at(older));
    });

    test('are read as before', () async {
      expect(await storage.getAccessToken(), 'a');
      expect(await storage.getRefreshToken(), 'r');
    });

    test('are deleted by a sign-out, though not yet moved', () async {
      await storage.clearTokens();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(keychain.values, {'saved:/user/profile': '{}'});
    });

    test('are listed with the new ones, and cleared with them', () async {
      await storage.write(key: 'saved:/events/1', value: '{}');

      expect(
          (await storage.readAll()).keys,
          unorderedEquals([
            'access_token',
            'refresh_token',
            'saved:/user/profile',
            'saved:/events/1'
          ]));

      await storage.clearAll();
      expect(keychain.values, isEmpty);
    });

    test('move to this phone when written again', () async {
      await storage.saveAccessToken('a2');

      expect(keychain.valuesAt(thisDevice), {'access_token': 'a2'});
      expect(keychain.valuesAt(older),
          {'refresh_token': 'r', 'saved:/user/profile': '{}'});
    });

    test('without the older store (Android, tests), only the one store',
        () async {
      final plain = SecureStorageService(storage: keychain.at(thisDevice));
      await plain.clearTokens();
      // At the older level, so out of this store's reach.
      expect(keychain.values['access_token'], 'a');
    });
  });
}
