import 'package:myotherapp/core/error/either.dart';
import 'package:myotherapp/core/usecases/usecase.dart';
import 'package:myotherapp/features/auth/domain/entities/user_entity.dart';
import 'package:myotherapp/features/auth/domain/repositories/auth_repository.dart';

/// Use case for signing in with Google.
class SignInWithGoogleUseCase extends UseCase<AuthTokens, GoogleCredentials> {
  final AuthRepository repository;

  SignInWithGoogleUseCase(this.repository);

  @override
  Future<Result<AuthTokens>> call(GoogleCredentials params) {
    return repository.signInWithGoogle(params);
  }
}

/// Use case for signing out.
class SignOutUseCase extends NoParamsUseCase<void> {
  final AuthRepository repository;

  SignOutUseCase(this.repository);

  @override
  Future<Result<void>> call() {
    return repository.signOut();
  }
}

/// Use case for checking authentication status.
class CheckAuthStatusUseCase extends NoParamsUseCase<AuthTokens?> {
  final AuthRepository repository;

  CheckAuthStatusUseCase(this.repository);

  @override
  Future<Result<AuthTokens?>> call() {
    return repository.getStoredTokens();
  }
}

/// Use case for refreshing authentication token.
class RefreshTokenUseCase extends UseCase<AuthTokens, String> {
  final AuthRepository repository;

  RefreshTokenUseCase(this.repository);

  @override
  Future<Result<AuthTokens>> call(String refreshToken) {
    return repository.refreshToken(refreshToken);
  }
}
