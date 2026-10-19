import 'package:finnet/core/api/api_helper.dart';

class AuthenticationService {
  AuthenticationService({APIService? api}) : _apiOverride = api;

  final APIService? _apiOverride;

  /// The app's API client; a test hands in its own.
  APIService get _api => _apiOverride ?? APIService.instance;

  /// What a sign-in call throws when it answers 2xx without tokens. Never
  /// the response body: that is what the sign-in screen used to show.
  static Exception _noTokens() =>
      Exception("We couldn't sign you in. Please try again.");

  /// `POST /auth/token`. [totpCode] is the second step for an account with
  /// two-step verification on: the authenticator's six digits, or one of
  /// its recovery codes. Without it such an account is refused with
  /// TOTP_REQUIRED (after the password is checked); a wrong one is
  /// TOTP_INVALID.
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    // OAuth2 token endpoint requires application/x-www-form-urlencoded
    // Dio's FormData sends multipart/form-data, so we need to send as encoded string
    final code = totpCode?.trim() ?? '';
    final encodedData =
        'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}'
        '${code.isEmpty ? '' : '&totp_code=${Uri.encodeComponent(code)}'}';

    final response = await _api.request(
      '/auth/token',
      DioMethod.post,
      contentType: 'application/x-www-form-urlencoded',
      formData: encodedData,
      skipAuth: true,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return response.data;
    }
    throw _noTokens();
  }

  Future<Map<String, dynamic>> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _api.request(
      '/user/register',
      DioMethod.post,
      param: {
        'full_name': fullName,
        'email': email,
        'password': password,
      },
      skipAuth: true,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return response.data;
    }
    throw Exception("We couldn't create your account. Please try again.");
  }

  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
    required String platform,
  }) async {
    final response = await _api.request(
      '/auth/google',
      DioMethod.post,
      param: {
        'id_token': idToken,
        'platform': platform,
      },
      skipAuth: true,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return response.data;
    }
    throw _noTokens();
  }

  Future<Map<String, dynamic>> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? userName,
    String? userEmail,
  }) async {
    final response = await _api.request(
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
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return response.data;
    }
    throw _noTokens();
  }

  /// The kind of account [accessToken] belongs to -- `app_user`, `club`,
  /// `admin` or `guest` -- from `GET /auth/me`.
  ///
  /// Sent with the new token by hand: it is not stored yet, and must not be
  /// until it is known to be an account the app can use.
  Future<String?> accountTypeOf(String accessToken) async {
    final response = await _api.request(
      '/auth/me',
      DioMethod.get,
      skipAuth: true,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = response.data;
    final type = data is Map ? data['user_type'] : null;
    return type is String ? type : null;
  }
}
