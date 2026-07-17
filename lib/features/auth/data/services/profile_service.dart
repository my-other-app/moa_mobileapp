import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import '../models/profile.dart';

class ProfileService {
  final Dio _dio;

  ProfileService({Dio? dio}) : _dio = dio ?? APIService.instance.dio;

  Future<Profile> getProfile(String accessToken) async {
    try {
      final response = await _dio.get(
        '/user/profile/me',
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
        }),
      );
      return Profile.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Failed to fetch profile: ${e.message ?? e.error ?? 'Unknown error'}',
      );
    }
  }
}
