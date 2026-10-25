import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('where the sign-in tokens are kept', () {
    const store = SecureStorageService.platformStorage;

    test('Android: EncryptedSharedPreferences, under the Keystore', () {
      expect(store.aOptions.toMap()['encryptedSharedPreferences'], 'true');
    });

    test(
        'iOS: the Keychain, readable once the phone is first unlocked, and '
        'not synced to other devices', () {
      final ios = store.iOptions.toMap();
      expect(ios['accessibility'], 'first_unlock');
      expect(ios['synchronizable'], 'false');
    });

    test('the service uses that store unless a test hands in another', () async {
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
      expect(await storage.readAll(), {'privacy_choices': '{"analytics":false}'});
    });

    test('clearAll empties the store', () async {
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
      await storage.write(key: 'other', value: 'x');

      await storage.clearAll();

      expect(await storage.readAll(), isEmpty);
      expect(await storage.containsKey(key: 'access_token'), isFalse);
    });
  });
}
