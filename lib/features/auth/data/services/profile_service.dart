import 'package:dio/dio.dart';
import '../models/profile.dart';

class ProfileService {
  final Dio _dio;

//TODO: Should use network service;
  ProfileService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.myotherapp.com/api/v1',
                headers: {'Content-Type': 'application/json'},
              ),
            );
  //TODO: need to get access token through service locator
  Future<Profile> getProfile(String accessToken) async {
    final response = await _dio.get(
      '/user/profile/me',
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
      }),
    );
    // Print the raw JSON response from the API
    return Profile.fromJson(response.data);
  }
}
