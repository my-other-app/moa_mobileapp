import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show
        FlutterSecureStorage,
        AndroidOptions,
        IOSOptions,
        KeychainAccessibility;
import 'package:myotherapp/core/secure_storage/token_model.dart';

const FlutterSecureStorage storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

class SecureStorage {
  // Private static instance variable
  static SecureStorage? _instance;

  // Private constructor to prevent external instantiation
  SecureStorage._();

  // Static getter to provide access to the instance
  static SecureStorage get instance {
    _instance ??= SecureStorage._(); // Create instance if not already created
    return _instance!;
  }

  Future<void> updateTokens(TokenModel tokenModel) async {
    // Security: Never log tokens
    await storage.write(key: 'access_token', value: tokenModel.accessToken);
    await storage.write(key: 'refresh_token', value: tokenModel.refreshToken);
  }

  Future<void> deleteTokens() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    // Security: No logging of token operations
  }

  Future<TokenModel> getAccessToken() async {
    final String? accessToken = await storage.read(key: 'access_token');
    final String? refreshToken = await storage.read(key: 'refresh_token');
    if (accessToken == null || refreshToken == null) {
      throw Exception('Access token or refresh token not found');
    }
    return TokenModel(accessToken: accessToken, refreshToken: refreshToken);
  }
}
