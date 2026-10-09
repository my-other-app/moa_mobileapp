import 'package:finnet/features/auth/domain/entities/user_entity.dart';

/// Read a token the server must have sent.
///
/// The fallback here used to be `?? ''`, which turned a response missing its
/// token into a sign-in that *succeeded* with an empty credential: the empty
/// string went into secure storage, the app navigated to the home screen,
/// and every request from then on sent `Authorization: Bearer ` and 401'd.
/// The user saw an app that had logged them in and then refused to do
/// anything, with no way to tell what was wrong.
///
/// Both the social sign-in and refresh endpoints always put access_token and
/// refresh_token in the body on success (app/api/auth/router.py returns a
/// `Token`, alongside setting cookies), so an absent or blank one is a
/// broken response, not a variant to absorb.
String _requiredToken(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException(
    'Auth response is missing "$key"; refusing to treat it as a sign-in',
  );
}

/// Data model for authentication tokens from API.
class AuthTokensModel {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;

  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    return AuthTokensModel(
      accessToken: _requiredToken(json, 'access_token'),
      refreshToken: _requiredToken(json, 'refresh_token'),
      expiresIn: json['expires_in'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (expiresIn != null) 'expires_in': expiresIn,
    };
  }

  /// Convert to domain entity.
  AuthTokens toEntity() {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn!))
          : null,
    );
  }

  /// Create from domain entity.
  factory AuthTokensModel.fromEntity(AuthTokens entity) {
    return AuthTokensModel(
      accessToken: entity.accessToken,
      refreshToken: entity.refreshToken,
    );
  }
}

/// Data model for Google sign-in request.
class GoogleSignInRequest {
  final String idToken;
  final String platform;

  const GoogleSignInRequest({
    required this.idToken,
    required this.platform,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_token': idToken,
      'platform': platform,
    };
  }
}

/// Data model for Google sign-in response.
class GoogleSignInResponse {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;
  final UserModel? user;

  const GoogleSignInResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    this.user,
  });

  factory GoogleSignInResponse.fromJson(Map<String, dynamic> json) {
    return GoogleSignInResponse(
      accessToken: _requiredToken(json, 'access_token'),
      refreshToken: _requiredToken(json, 'refresh_token'),
      expiresIn: json['expires_in'] as int?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  AuthTokens toTokensEntity() {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn!))
          : null,
    );
  }
}

/// Data model for basic user info from API.
class UserModel {
  final int id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? username;

  const UserModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.username,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'username': username,
    };
  }

  User toEntity() {
    return User(
      id: id.toString(),
      fullName: fullName ?? '',
      email: email ?? '',
      phone: phone,
    );
  }
}
