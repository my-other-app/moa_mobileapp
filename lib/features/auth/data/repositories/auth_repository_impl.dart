import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:finnet/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:finnet/features/auth/data/models/auth_models.dart';
import 'package:finnet/features/auth/domain/entities/user_entity.dart';
import 'package:finnet/features/auth/domain/repositories/auth_repository.dart';

/// Provider for the auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

/// Implementation of auth repository.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<AuthTokens>> signInWithGoogle(
      GoogleCredentials credentials) async {
    try {
      final response = await remoteDataSource.signInWithGoogle(
        idToken: credentials.idToken,
        platform: credentials.platform,
      );

      final tokens = response.toTokensEntity();

      // Save tokens locally
      final tokensModel = AuthTokensModel(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      await localDataSource.saveTokens(tokensModel);

      return Either.right(tokens);
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('AuthRepository.signInWithGoogle error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await localDataSource.clearTokens();
      return Either.right(null);
    } catch (e) {
      debugPrint('AuthRepository.signOut error: $e');
      return Either.left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<AuthTokens?>> getStoredTokens() async {
    try {
      final tokensModel = await localDataSource.getStoredTokens();
      if (tokensModel == null) {
        return Either.right(null);
      }
      return Either.right(tokensModel.toEntity());
    } catch (e) {
      debugPrint('AuthRepository.getStoredTokens error: $e');
      return Either.left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> saveTokens(AuthTokens tokens) async {
    try {
      final tokensModel = AuthTokensModel(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      await localDataSource.saveTokens(tokensModel);
      return Either.right(null);
    } catch (e) {
      debugPrint('AuthRepository.saveTokens error: $e');
      return Either.left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> clearTokens() async {
    try {
      await localDataSource.clearTokens();
      return Either.right(null);
    } catch (e) {
      debugPrint('AuthRepository.clearTokens error: $e');
      return Either.left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<AuthTokens>> refreshToken(String refreshToken) async {
    try {
      final response = await remoteDataSource.refreshToken(refreshToken);
      final tokens = response.toEntity();

      // Save new tokens
      await localDataSource.saveTokens(response);

      return Either.right(tokens);
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('AuthRepository.refreshToken error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return await localDataSource.isAuthenticated();
  }

  /// Map API exceptions to domain failures.
  Failure _mapApiExceptionToFailure(ApiException e) {
    switch (e.type) {
      case ApiExceptionType.network:
        return NetworkFailure(message: e.message);
      case ApiExceptionType.unauthorized:
        return AuthFailure(message: e.message);
      case ApiExceptionType.forbidden:
        return AuthFailure(message: e.message);
      case ApiExceptionType.badRequest:
        return ValidationFailure(message: e.message);
      case ApiExceptionType.notFound:
        return ServerFailure(message: e.message, code: '404');
      case ApiExceptionType.server:
        return ServerFailure(message: e.message);
      case ApiExceptionType.timeout:
        return NetworkFailure(message: e.message);
      case ApiExceptionType.cancelled:
        return UnknownFailure(message: e.message);
      case ApiExceptionType.unknown:
        return UnknownFailure(message: e.message);
    }
  }
}
