import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/domain/entities/user_entity.dart';

/// Repository interface for authentication operations.
///
/// This defines the contract for auth-related data operations.
/// The implementation will be in the data layer.
abstract class AuthRepository {
  /// Sign in with Google credentials.
  ///
  /// Returns [AuthTokens] on success or a [Failure] on error.
  Future<Result<AuthTokens>> signInWithGoogle(GoogleCredentials credentials);

  /// Sign out the current user.
  Future<Result<void>> signOut();

  /// Get the current authentication tokens.
  Future<Result<AuthTokens?>> getStoredTokens();

  /// Save authentication tokens.
  Future<Result<void>> saveTokens(AuthTokens tokens);

  /// Clear stored tokens (logout).
  Future<Result<void>> clearTokens();

  /// Refresh the access token using refresh token.
  Future<Result<AuthTokens>> refreshToken(String refreshToken);

  /// Check if the user is currently authenticated.
  Future<bool> isAuthenticated();
}
