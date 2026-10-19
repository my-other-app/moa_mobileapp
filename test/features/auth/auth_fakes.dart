import 'dart:convert';

import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';

/// Secure storage in a map, without the platform channel.
class MemoryStorage extends SecureStorageService {
  MemoryStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> getAccessToken() async => values['access_token'];

  @override
  Future<String?> getRefreshToken() async => values['refresh_token'];

  @override
  Future<void> saveAccessToken(String token) async =>
      values['access_token'] = token;

  @override
  Future<void> saveRefreshToken(String token) async =>
      values['refresh_token'] = token;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    values['access_token'] = accessToken;
    values['refresh_token'] = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    values.remove('access_token');
    values.remove('refresh_token');
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> clearAll() async => values.clear();

  @override
  Future<Map<String, String>> readAll() async => {...values};
}

/// Records what sign-in and sign-out asked of push registration.
class FakePushRegistration implements PushRegistration {
  final List<String> calls = [];

  /// Runs when the server is asked to forget the token, to look at the
  /// state of things at that moment.
  Future<void> Function()? onServerUnregister;

  @override
  Future<void> onSignedIn() async => calls.add('signedIn');

  @override
  Future<void> onSessionRestored() async => calls.add('restored');

  @override
  Future<void> unregisterOnServer() async {
    calls.add('serverUnregistered');
    await onServerUnregister?.call();
  }

  @override
  Future<void> onSignedOut() async => calls.add('signedOut');
}

/// Records which sessions were ended on the server.
class FakeSessionRevoker implements SessionRevoker {
  final List<String> revoked = [];
  final List<bool> stored = [];

  /// Runs inside [revoke], to look at -- or delay -- what happens then.
  Future<void> Function()? during;

  @override
  Future<void> revoke(String accessToken, {bool stored = false}) async {
    revoked.add(accessToken);
    this.stored.add(stored);
    await during?.call();
  }
}

/// A JWT-shaped token whose payload carries [sid]. Unsigned: the app never
/// checks the signature, only reads which session the token belongs to.
String tokenWithSid(String? sid) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return [
    part({'alg': 'HS256', 'typ': 'JWT'}),
    part({
      'user_id': 7,
      'token_type': 'access_token',
      if (sid != null) 'sid': sid,
    }),
    'signature',
  ].join('.');
}
