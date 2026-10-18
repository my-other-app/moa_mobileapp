import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/auth/data/models/auth_models.dart';

/// Provider for the auth remote data source.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteDataSourceImpl(dio);
});

/// Abstract interface for remote auth operations.
abstract class AuthRemoteDataSource {
  /// Sign in with Google credentials.
  Future<GoogleSignInResponse> signInWithGoogle({
    required String idToken,
    required String platform,
  });
}

/// Implementation of auth remote data source.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<GoogleSignInResponse> signInWithGoogle({
    required String idToken,
    required String platform,
  }) async {
    final response = await _dio.post(
      '/auth/google',
      data: {
        'id_token': idToken,
        'platform': platform,
      },
    );

    return GoogleSignInResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
