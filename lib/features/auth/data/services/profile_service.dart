import 'package:dio/dio.dart';
import '../models/profile.dart';

class ProfileService {
  final Dio _dio;

  ProfileService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.staging.myotherapp.com/api/v1',
                headers: {'Content-Type': 'application/json'},
              ),
            );

  Future<Profile> getProfile(String accessToken) async {
    final response = await _dio.get(
      '/user/profile/me',
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
      }),
    );
    // Print the raw JSON response from the API
    print("Raw profile API response: ${response.data}");
    return Profile.fromJson(response.data);
  }
}
