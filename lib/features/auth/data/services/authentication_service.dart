import 'package:myotherapp/core/api/api_helper.dart';

class AuthenticationService {
  // final Dio _dio;

  // AuthenticationService({Dio? dio})
  //     : _dio = dio ??
  //           Dio(
  //             BaseOptions(
  //               baseUrl: 'https://api.staging.myotherapp.com/api/v1',
  //               headers: {'Content-Type': 'application/json'},
  //             ),
  //           );

  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
    required String platform,
  }) async {
    // final response = await _dio.post(
    //   '/auth/google',
    //   data: {
    //     'id_token': idToken,
    //     'platform': platform,
    //   },
    // );
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
}
