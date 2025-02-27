import 'package:dio/dio.dart';

class AuthenticationService {

  final Dio _dio;

  AuthenticationService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.staging.myotherapp.com/api/v1',
                headers: {'Content-Type': 'application/json'},
              ),
            );

  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
    required String platform,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google',
        data: {
          'id_token': idToken,
          'platform': platform,
        },
      );
      return response.data;
    } on DioException catch (e) {
      // Handle specific errors (e.g., 422 validation errors)
      if (e.response?.statusCode == 422) {
        throw Exception('Validation Error: ${e.response?.data}');
      } else {
        throw Exception('Login failed: ${e.message}');
      }
    }
  }
}
