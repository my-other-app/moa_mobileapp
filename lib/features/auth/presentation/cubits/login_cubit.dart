import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:finnet/common/models/user/user_model.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/data/services/authentication_service.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/sign_in_errors.dart';

/// Login States
abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final String accessToken;
  final String refreshToken;
  final String photoUrl;
  final UserModel? user;

  /// Set only by an email sign-up: the address a verification code was just
  /// sent to, so the next screen can ask for it.
  final String? signedUpEmail;

  LoginSuccess({
    required this.accessToken,
    required this.refreshToken,
    required this.photoUrl,
    this.user,
    this.signedUpEmail,
  });
}

class Logout extends LoginState {}

class LoginFailure extends LoginState {
  final String error;
  LoginFailure({required this.error});
}

/// Login Cubit - converted to callback-based class (no Bloc dependency).
///
/// A failure reaches the screen as [LoginFailure.error], already worded for
/// a person by [signInErrorMessage]. It used to be `e.toString()`: a
/// mistyped password showed "Error: ApiException: Unauthorized. Please log
/// in again. (unauthorized, code: 401)".
class LoginCubit {
  final AuthenticationService authService;
  final ProfileService profileService;
  final SecureStorageService secureStorage;
  final SessionRevoker sessionRevoker;

  LoginState _state = LoginInitial();
  LoginState get state => _state;

  // Callback for state changes
  void Function(LoginState)? onStateChanged;

  LoginCubit({
    required this.authService,
    required this.profileService,
    required this.secureStorage,
    this.sessionRevoker = const ApiSessionRevoker(),
  });

  void _emit(LoginState state) {
    _state = state;
    onStateChanged?.call(state);
  }

  void _fail(String method, Object error) {
    debugPrint('LoginCubit: $method sign-in failed: $error');
    _emit(LoginFailure(error: signInErrorMessage(error)));
  }

  /// The two tokens from a sign-in answer. One without both is a failed
  /// sign-in, not a success holding nulls.
  static ({String access, String refresh}) _tokensFrom(
      Map<String, dynamic> result) {
    final access = result['access_token'];
    final refresh = result['refresh_token'];
    if (access is String &&
        access.isNotEmpty &&
        refresh is String &&
        refresh.isNotEmpty) {
      return (access: access, refresh: refresh);
    }
    throw Exception(signInFailedMessage);
  }

  Future<void> loginWithGoogle(
      String idToken, String platform, String photoUrl) async {
    _emit(LoginLoading());

    try {
      final result = await authService.signInWithGoogle(
        idToken: idToken,
        platform: platform,
      );
      final tokens = _tokensFrom(result);

      // Store tokens in secure storage
      await secureStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );

      _emit(LoginSuccess(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
        photoUrl: photoUrl,
      ));
    } catch (e) {
      _fail('Google', e);
    }
  }

  Future<void> loginWithApple(
    String identityToken,
    String authorizationCode,
    String? userName,
    String? userEmail,
  ) async {
    _emit(LoginLoading());

    try {
      final result = await authService.signInWithApple(
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        userName: userName,
        userEmail: userEmail,
      );
      final tokens = _tokensFrom(result);

      // Store tokens in secure storage
      await secureStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );

      _emit(LoginSuccess(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
        photoUrl: '', // Apple doesn't provide profile photo
      ));
    } catch (e) {
      _fail('Apple', e);
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    _emit(LoginLoading());

    try {
      final result = await authService.signInWithEmail(
        email: email,
        password: password,
      );
      final tokens = _tokensFrom(result);
      // Google and Apple only ever sign in attendee accounts; a password can
      // belong to a club. Checked before the tokens are stored, so a club's
      // session never becomes the app's.
      await _refuseClubAccount(tokens.access);

      // Store tokens in secure storage
      await secureStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );

      _emit(LoginSuccess(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
        photoUrl: '', // Email login doesn't provide profile photo
      ));
    } catch (e) {
      _fail('email', e);
    }
  }

  Future<void> signUpWithEmail(
      String fullName, String email, String password) async {
    _emit(LoginLoading());

    try {
      final result = await authService.signUpWithEmail(
        fullName: fullName,
        email: email,
        password: password,
      );
      final tokens = _tokensFrom(result);

      // Store tokens in secure storage
      await secureStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );

      _emit(LoginSuccess(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
        photoUrl: '', // Email signup doesn't provide profile photo
        signedUpEmail: email,
      ));
    } catch (e) {
      _fail('sign-up', e);
    }
  }

  /// Throw [ClubAccountSignIn] if [accessToken] is a club's, after ending
  /// the session the sign-in just opened.
  ///
  /// An unverified club is refused by `/auth/me` itself (CLUB_NOT_VERIFIED).
  /// When the answer cannot be had at all -- no connection, a server error --
  /// the sign-in goes ahead: an attendee must not be locked out by a failed
  /// check, and the profile check that follows refuses a club anyway.
  Future<void> _refuseClubAccount(String accessToken) async {
    String? type;
    try {
      type = await authService.accountTypeOf(accessToken);
    } catch (e) {
      final code = errorCodeOf(e);
      if (code == 'ACCOUNT_SUSPENDED') rethrow;
      if (code != 'CLUB_NOT_VERIFIED') {
        debugPrint('LoginCubit: could not check the account type: $e');
        return;
      }
      type = 'club';
    }
    if (type == 'club') {
      unawaited(sessionRevoker.revoke(accessToken));
      throw const ClubAccountSignIn();
    }
  }
}
