import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/auth/data/services/password_reset_service.dart';

/// Why a password change did not go through.
enum ChangePasswordErrorKind {
  /// The current password typed is not the account's. It counts toward the
  /// account's lockout, as a wrong sign-in does.
  wrongCurrent,

  /// Too many wrong passwords: the account is locked for a while
  /// (LOGIN_LOCKED), or too many tries this minute.
  throttled,

  /// The new password was refused as typed (fewer than 6 characters).
  invalidInput,

  /// No connection, or it timed out.
  network,

  unknown,
}

class ChangePasswordException implements Exception {
  const ChangePasswordException(this.kind, this.message);

  final ChangePasswordErrorKind kind;
  final String message;

  static const wrongCurrentMessage = "That isn't your current password.";

  /// The server's answer to `POST /auth/change-password`: 400 "Incorrect old
  /// password", 429 LOGIN_LOCKED ("Too many wrong passwords. Try again in N
  /// min.") or the limiter's, 422 for a new password it refused.
  factory ChangePasswordException.from(Object error) {
    final dio = error is DioException ? error : null;
    final api = error is ApiException
        ? error
        : (dio?.error is ApiException ? dio!.error as ApiException : null);
    if (api?.type == ApiExceptionType.network ||
        api?.type == ApiExceptionType.timeout ||
        dio?.type == DioExceptionType.connectionError ||
        dio?.type == DioExceptionType.connectionTimeout ||
        dio?.type == DioExceptionType.sendTimeout ||
        dio?.type == DioExceptionType.receiveTimeout) {
      return const ChangePasswordException(
          ChangePasswordErrorKind.network, PasswordResetException.networkMessage);
    }
    final status = api?.statusCode ?? dio?.response?.statusCode;
    final said = api?.serverMessage;
    if (status == 400) {
      return const ChangePasswordException(
          ChangePasswordErrorKind.wrongCurrent, wrongCurrentMessage);
    }
    if (status == 429) {
      return ChangePasswordException(
        ChangePasswordErrorKind.throttled,
        api?.errorCode == 'LOGIN_LOCKED' && said != null && said.isNotEmpty
            ? said
            : 'Too many tries. Wait a minute and try again.',
      );
    }
    if (status == 422) {
      return const ChangePasswordException(
        ChangePasswordErrorKind.invalidInput,
        'Use at least 6 characters for your new password.',
      );
    }
    if (status != null && status >= 500) {
      return const ChangePasswordException(
          ChangePasswordErrorKind.unknown, PasswordResetException.serverMessage);
    }
    return const ChangePasswordException(
      ChangePasswordErrorKind.unknown,
      "We couldn't change your password. Please try again.",
    );
  }

  @override
  String toString() => 'ChangePasswordException(${kind.name}): $message';
}

/// "Change password" for an email/password account, on the server's
/// contract (`app/api/auth/router.py` `change_password`):
///
/// `POST /auth/change-password {old_password, new_password}` sets the new
/// password and bumps the account's token version, which ends every session
/// it had -- this phone's too. So the app signs in again at once with the
/// new password ([signInAgain], `POST /auth/token`) and carries on with the
/// new session. An account with two-step verification cannot be signed in
/// without its authenticator's code; then the person signs in again.
class ChangePasswordService {
  ChangePasswordService({Dio? dio}) : _dio = dio ?? APIService.instance.dio;

  final Dio _dio;

  Future<void> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<dynamic>('/auth/change-password', data: {
        'old_password': currentPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      throw ChangePasswordException.from(e);
    }
  }

  /// The new session, or null when the account cannot be signed in
  /// without more (two-step verification) or the sign-in failed. Never
  /// throws: the password is changed either way.
  Future<PasswordResetTokens?> signInAgain({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/token',
        data: 'username=${Uri.encodeComponent(email)}'
            '&password=${Uri.encodeComponent(password)}',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          extra: {'skipAuth': true},
        ),
      );
      final data = response.data;
      final access = data is Map ? data['access_token'] : null;
      final refresh = data is Map ? data['refresh_token'] : null;
      if (access is String &&
          access.isNotEmpty &&
          refresh is String &&
          refresh.isNotEmpty) {
        return PasswordResetTokens(accessToken: access, refreshToken: refresh);
      }
    } catch (_) {
      // Two-step verification, or no answer: they sign in again themselves.
    }
    return null;
  }
}

final changePasswordServiceProvider =
    Provider<ChangePasswordService>((ref) => ChangePasswordService());
