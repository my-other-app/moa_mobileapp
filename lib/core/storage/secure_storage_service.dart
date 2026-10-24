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

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

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
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  // General Key-Value Operations

  /// Write a value to secure storage.
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value from secure storage.
  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  /// Every key and value in this container.
  Future<Map<String, String>> readAll() => _storage.readAll();

  /// Delete a value from secure storage.
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  /// Clear all values from secure storage.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if a key exists in secure storage.
  Future<bool> containsKey({required String key}) async {
    return await _storage.containsKey(key: key);
  }
}
