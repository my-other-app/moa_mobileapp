import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:finnet/core/api/api_helper.dart';

/// Apple's side of "Sign in with Apple", as the sign-in screen uses it:
/// whether this device offers it, and the credential Apple's sheet hands
/// back. [platform] is the real one; a test hands in its own.
class AppleSignIn {
  const AppleSignIn({required this.isAvailable, required this.credential});

  final Future<bool> Function() isAvailable;
  final Future<AuthorizationCredentialAppleID> Function() credential;

  static final platform = AppleSignIn(
    isAvailable: AppleAuthService.isAvailable,
    credential: () => SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    ),
  );
}

/// Service for handling Apple Sign In authentication.
class AppleAuthService {
  /// Check if Apple Sign In is available on this device.
  ///
  /// Returns true only on:
  /// - iOS 13.0+
  /// - macOS 10.15+
  static Future<bool> isAvailable() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }
    return await SignInWithApple.isAvailable();
  }

  /// Initiate Apple Sign In flow and authenticate with backend.
  ///
  /// Returns the authentication response containing access and refresh tokens,
  /// or throws an exception if sign in fails.
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      // Request Apple Sign In credentials
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Construct user name from parts if available (only on first sign in)
      String? userName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [credential.givenName, credential.familyName]
            .where((part) => part != null && part.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          userName = parts.join(' ');
        }
      }

      // Send to backend for verification and user creation/login
      final response = await APIService.instance.request(
        '/auth/apple',
        DioMethod.post,
        param: {
          'identity_token': credential.identityToken,
          'authorization_code': credential.authorizationCode,
          'user_name': userName,
          'user_email': credential.email,
        },
        skipAuth: true,
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      throw Exception('Apple Sign In failed: ${response.data}');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('Sign in was cancelled');
      } else if (e.code == AuthorizationErrorCode.failed) {
        throw Exception('Sign in failed: ${e.message}');
      } else if (e.code == AuthorizationErrorCode.invalidResponse) {
        throw Exception('Invalid response from Apple');
      } else if (e.code == AuthorizationErrorCode.notHandled) {
        throw Exception('Sign in not handled');
      } else if (e.code == AuthorizationErrorCode.notInteractive) {
        throw Exception('Sign in requires user interaction');
      }
      throw Exception('Unknown Apple Sign In error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
