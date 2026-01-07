import 'package:equatable/equatable.dart';

/// User entity representing an authenticated user.
///
/// This is a domain entity - it contains only the data needed
/// for business logic, without serialization concerns.
class User extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isProfileComplete;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.isProfileComplete = false,
  });

  /// Creates a copy with updated values.
  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? isProfileComplete,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }

  @override
  List<Object?> get props =>
      [id, fullName, email, phone, avatarUrl, isProfileComplete];
}

/// Authentication tokens entity.
class AuthTokens extends Equatable {
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  /// Check if the token is expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresAt];
}

/// Google sign-in credentials.
class GoogleCredentials extends Equatable {
  final String idToken;
  final String platform;
  final String? photoUrl;

  const GoogleCredentials({
    required this.idToken,
    required this.platform,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [idToken, platform, photoUrl];
}
