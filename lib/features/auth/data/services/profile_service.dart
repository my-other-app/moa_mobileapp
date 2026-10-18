import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import '../models/profile.dart';

class ProfileService {
  final Dio _dio;

  ProfileService({Dio? dio}) : _dio = dio ?? APIService.instance.dio;

  /// The signed-in person's profile. A failure is thrown as Dio threw it,
  /// for `extractErrorMessage` to word: it used to be re-thrown as
  /// `Exception('Failed to fetch profile: $error')`, and the ApiException's
  /// `toString()` inside it reached the screen.
  Future<Profile> getProfile(String accessToken) async {
    final response = await _dio.get(
      '/user/profile/me',
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
      }),
    );
    return Profile.fromJson(response.data);
  }
}
