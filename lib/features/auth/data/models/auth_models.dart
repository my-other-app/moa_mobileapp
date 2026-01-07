import 'package:myotherapp/features/auth/domain/entities/user_entity.dart';

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
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
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
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
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
