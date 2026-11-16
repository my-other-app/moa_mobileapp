import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for SecureStorageService.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Service for secure storage operations.
///
/// Uses flutter_secure_storage for encrypted key-value storage.
class SecureStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  /// Android: EncryptedSharedPreferences, under a key in this phone's
  /// Keystore.
  static const androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  /// How readable an entry is on an iPhone: once the phone has been
  /// unlocked after a restart (so a push arriving in the background can
  /// still be handled), and on this phone only. A "this device" entry is
  /// never carried to another iPhone by an encrypted backup or a transfer:
  /// a new phone starts signed out.
  static const iosAccessibility =
      KeychainAccessibility.first_unlock_this_device;

  /// What builds up to 1.3.0 wrote with: the same, but carried to a new
  /// iPhone by an encrypted backup. Start-up moves such entries over
  /// (`KeychainStartUp`); until it has, this service still deletes and
  /// lists them, so a sign-out never leaves one behind.
  static const legacyIosAccessibility = KeychainAccessibility.first_unlock;

  /// The phone's own store, encrypted: the Android Keystore behind
  /// EncryptedSharedPreferences, the iOS Keychain at [iosAccessibility].
  static const FlutterSecureStorage platformStorage = FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: IOSOptions(accessibility: iosAccessibility),
  );

  /// The same store, as builds up to 1.3.0 opened it. On an iPhone a
  /// listing or a delete only sees entries of its own accessibility (a
  /// read and a write see them all); on Android it is [platformStorage].
  static const FlutterSecureStorage legacyPlatformStorage =
      FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: IOSOptions(accessibility: legacyIosAccessibility),
  );

  /// The store with its iOS entries at [level]: what start-up uses to find,
  /// move and (on a new install) delete entries of every accessibility.
  static FlutterSecureStorage storageAt(KeychainAccessibility level) =>
      FlutterSecureStorage(
        aOptions: androidOptions,
        iOptions: IOSOptions(accessibility: level),
      );

  final FlutterSecureStorage _storage;

  /// [legacyPlatformStorage] on an iPhone; null elsewhere, and whenever a
  /// test hands in its own store.
  final FlutterSecureStorage? _legacy;

  SecureStorageService({
    FlutterSecureStorage? storage,
    FlutterSecureStorage? legacy,
  })  : _storage = storage ?? platformStorage,
        _legacy = legacy ??
            (storage == null && Platform.isIOS ? legacyPlatformStorage : null);

  // Token Management

  /// Save access token.
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Get access token.
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// Save refresh token.
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Get refresh token.
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Save both tokens together.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ]);
  }

  /// Clear all tokens (for logout).
  Future<void> clearTokens() async {
    await Future.wait([
      delete(key: _accessTokenKey),
      delete(key: _refreshTokenKey),
    ]);
  }

  // General Key-Value Operations

  /// Write a value to secure storage. On an iPhone this also moves an
  /// entry an older build wrote to [iosAccessibility].
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value from secure storage, whatever build wrote it.
  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  /// Every key and value in this container, whatever build wrote them.
  Future<Map<String, String>> readAll() async {
    final legacy = _legacy;
    if (legacy == null) return _storage.readAll();
    return {...await legacy.readAll(), ...await _storage.readAll()};
  }

  /// Delete a value from secure storage, whatever build wrote it.
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
    await _legacy?.delete(key: key);
  }

  /// Clear all values from secure storage.
  Future<void> clearAll() async {
    await _storage.deleteAll();
    await _legacy?.deleteAll();
  }

  /// Check if a key exists in secure storage.
  Future<bool> containsKey({required String key}) async {
    return await _storage.containsKey(key: key);
  }
}
