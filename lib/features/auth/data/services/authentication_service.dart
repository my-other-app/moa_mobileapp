import 'package:dio/dio.dart';
import 'package:myotherapp/core/api/api_helper.dart';

class AuthenticationService {
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await APIService.instance.request(
      '/auth/token',
      DioMethod.post,
      contentType: 'application/x-www-form-urlencoded',
      formData: FormData.fromMap({
        'username': email,
        'password': password,
      }),
      skipAuth: true,
    );
    if (response.statusCode == 200) return response.data;

    throw Exception('Login failed: ${response.data}');
  }

  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
    required String platform,
  }) async {
    final response = await APIService.instance.request(
      '/auth/google',
      DioMethod.post,
      param: {
        'id_token': idToken,
        'platform': platform,
      },
      skipAuth: true,
    );
    if (response.statusCode == 200) return response.data;

    throw Exception('Login failed: ${response.data}');
  }

  Future<Map<String, dynamic>> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? userName,
    String? userEmail,
  }) async {
    final response = await APIService.instance.request(
      '/auth/apple',
      DioMethod.post,
      param: {
        'identity_token': identityToken,
        'authorization_code': authorizationCode,
        'user_name': userName,
        'user_email': userEmail,
      },
      skipAuth: true,
    );
    if (response.statusCode == 200) return response.data;

    throw Exception('Apple login failed: ${response.data}');
  }
}
