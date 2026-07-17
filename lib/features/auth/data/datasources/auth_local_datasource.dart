import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/models/auth_models.dart';

/// Provider for the auth local data source.
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return AuthLocalDataSourceImpl(storageService);
});

/// Abstract interface for local auth operations.
abstract class AuthLocalDataSource {
  /// Get stored auth tokens.
  Future<AuthTokensModel?> getStoredTokens();

  /// Save auth tokens.
  Future<void> saveTokens(AuthTokensModel tokens);

  /// Clear stored tokens.
  Future<void> clearTokens();

  /// Check if user is authenticated.
  Future<bool> isAuthenticated();
}

/// Implementation of auth local data source.
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SecureStorageService _storageService;

  AuthLocalDataSourceImpl(this._storageService);

  @override
  Future<AuthTokensModel?> getStoredTokens() async {
    final accessToken = await _storageService.getAccessToken();
    final refreshToken = await _storageService.getRefreshToken();

    if (accessToken == null) {
      return null;
    }

    return AuthTokensModel(
      accessToken: accessToken,
      refreshToken: refreshToken ?? '',
    );
  }

  @override
  Future<void> saveTokens(AuthTokensModel tokens) async {
    await _storageService.saveAccessToken(tokens.accessToken);
    await _storageService.saveRefreshToken(tokens.refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storageService.clearAll();
  }

  @override
  Future<bool> isAuthenticated() async {
    final accessToken = await _storageService.getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }
}
