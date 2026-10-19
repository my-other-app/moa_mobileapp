import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';

/// Why a forgotten-password call did not go through, in the terms the reset
/// screen needs to say what happened and what to do next.
enum PasswordResetErrorKind {
  /// The code is not the one sent (or the address has no live code);
  /// [PasswordResetException.attemptsLeft] says how many tries remain.
  wrongCode,

  /// The code is old, used, or replaced by a newer one.
  expired,

  /// Five wrong tries: that code is dead and a new one is needed.
  tooManyAttempts,

  /// The account has two-step verification on: the authenticator's code (or
  /// a recovery code) is needed as well.
  totpRequired,

  /// The authenticator code sent with it was wrong (it counts as a try).
  totpInvalid,

  /// The new password (or the address) was refused as typed.
  invalidInput,

  /// Too many requests from this network.
  throttled,

  /// No connection, or it timed out.
  network,

  unknown,
}

class PasswordResetException implements Exception {
  final PasswordResetErrorKind kind;
  final String message;
  final int? attemptsLeft;

  const PasswordResetException(this.kind, this.message, {this.attemptsLeft});

  /// The code is dead: only a new one can go on.
  bool get needsNewCode =>
      kind == PasswordResetErrorKind.expired ||
      kind == PasswordResetErrorKind.tooManyAttempts;

  static const networkMessage =
      'No connection. Check your internet and try again.';
  static const throttledMessage =
      'Too many tries from this network. Wait a minute and try again.';
  static const serverMessage =
      'Something went wrong on our side. Please try again in a moment.';

  /// Reads the server's answer: `{message, error_code, errors:
  /// {attempts_left}}` from `/auth/password/reset`, FastAPI's `{detail:
  /// [...]}` for a field it refused, or the limiter's bare `{error: ...}`.
  factory PasswordResetException.fromResponse(int? status, Object? body) {
    String? code;
    Map<String, dynamic> errors = const {};
    if (body is Map) {
      final raw = body['error_code'];
      if (raw is String) code = raw;
      final rawErrors = body['errors'];
      if (rawErrors is Map) errors = Map<String, dynamic>.from(rawErrors);
    }
    final left = _int(errors['attempts_left']);

    switch (code) {
      case 'CODE_INVALID':
        return PasswordResetException(
          PasswordResetErrorKind.wrongCode,
          left == null
              ? "That code isn't right. Check the email address and the code."
              : "That code isn't right. Check the email address and the "
                  'code. $left ${left == 1 ? 'try' : 'tries'} left.',
          attemptsLeft: left,
        );
      case 'CODE_EXPIRED':
        return const PasswordResetException(
          PasswordResetErrorKind.expired,
          'That code has expired. Ask for a new one.',
          attemptsLeft: 0,
        );
      case 'CODE_LOCKED':
        return const PasswordResetException(
          PasswordResetErrorKind.tooManyAttempts,
          'Too many wrong tries. Ask for a new code.',
          attemptsLeft: 0,
        );
      case 'TOTP_REQUIRED':
        return const PasswordResetException(
          PasswordResetErrorKind.totpRequired,
          'This account uses two-step verification. Enter the code from your '
          'authenticator app as well.',
        );
      case 'TOTP_INVALID':
        return PasswordResetException(
          PasswordResetErrorKind.totpInvalid,
          left == null
              ? "That authenticator code isn't right."
              : "That authenticator code isn't right. $left "
                  '${left == 1 ? 'try' : 'tries'} left.',
          attemptsLeft: left,
        );
    }
    if (status == 422) {
      return const PasswordResetException(
        PasswordResetErrorKind.invalidInput,
        'Check the email address, and use a password of at least 6 '
        'characters.',
      );
    }
    if (status == 429) {
      return const PasswordResetException(
          PasswordResetErrorKind.throttled, throttledMessage);
    }
    if (status != null && status >= 500) {
      return const PasswordResetException(
          PasswordResetErrorKind.unknown, serverMessage);
    }
    return const PasswordResetException(
      PasswordResetErrorKind.unknown,
      "We couldn't reset your password. Please try again.",
    );
  }

  factory PasswordResetException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const PasswordResetException(
            PasswordResetErrorKind.network, networkMessage);
      default:
        return PasswordResetException.fromResponse(
          error.response?.statusCode,
          error.response?.data,
        );
    }
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  @override
  String toString() => 'PasswordResetException(${kind.name}): $message';
}

/// The session a successful reset opens: the same two tokens `/auth/token`
/// gives.
class PasswordResetTokens {
  final String accessToken;
  final String refreshToken;

  const PasswordResetTokens({
    required this.accessToken,
    required this.refreshToken,
  });
}

/// A forgotten password, on the backend's contract
/// (`app/api/auth/router.py`, `password_reset.py`):
///
/// 1. `POST /auth/password/forgot` with `{email}`. Always `200 {"sent":
///    true}`, whether or not the address has an account; when it has an
///    email/password app account, a six-digit code goes to it, good for 15
///    minutes. Google and Apple accounts get nothing.
/// 2. `POST /auth/password/reset` with `{email, code, new_password}` (and
///    `totp_code` for an account with two-step verification). On a match
///    the password is set, every other session ends, and the answer is the
///    tokens of a new session: the person is signed in.
///
/// Both are sent without the stored session ([skipAuth]): there is none,
/// and a 401 here (TOTP_REQUIRED) is about the code, not a session to
/// renew. Every failure is a [PasswordResetException].
class PasswordResetService {
  final Dio _dio;

  PasswordResetService({Dio? dio}) : _dio = dio ?? APIService.instance.dio;

  static final _noSession = Options(extra: {'skipAuth': true});

  Future<void> requestCode(String email) async {
    try {
      await _dio.post<dynamic>(
        '/auth/password/forgot',
        data: {'email': email.trim()},
        options: _noSession,
      );
    } on DioException catch (e) {
      throw PasswordResetException.fromDio(e);
    }
  }

  Future<PasswordResetTokens> reset({
    required String email,
    required String code,
    required String newPassword,
    String? totpCode,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/auth/password/reset',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'new_password': newPassword,
          if (totpCode != null && totpCode.trim().isNotEmpty)
            'totp_code': totpCode.trim(),
        },
        options: _noSession,
      );
    } on DioException catch (e) {
      throw PasswordResetException.fromDio(e);
    }
    final data = response.data;
    final access = data is Map ? data['access_token'] : null;
    final refresh = data is Map ? data['refresh_token'] : null;
    if (access is String &&
        access.isNotEmpty &&
        refresh is String &&
        refresh.isNotEmpty) {
      return PasswordResetTokens(accessToken: access, refreshToken: refresh);
    }
    // A 200 without a session: the password may well be set, so say so
    // rather than asking for it again.
    throw const PasswordResetException(
      PasswordResetErrorKind.unknown,
      'Your password may have been changed, but we could not sign you in. '
      'Try signing in with the new password.',
    );
  }
}
