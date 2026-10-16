import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';

/// Why a verification call did not go through, in the terms the verify
/// screen needs to say what happened and what to do next.
enum EmailVerificationErrorKind {
  /// The code typed is not the one sent; [EmailVerificationException.attemptsLeft] says how many tries remain.
  wrongCode,

  /// The code is too old, was replaced by a newer one, or none was sent.
  expired,

  /// Five wrong tries: that code is dead and a new one is needed.
  tooManyAttempts,

  /// Asked for a code too soon or too often; [EmailVerificationException.retryAfter] says when to ask again.
  throttled,

  /// Nothing to do: the address is verified already.
  alreadyVerified,

  /// The session is gone and could not be renewed.
  sessionExpired,

  /// No connection, or it timed out.
  network,

  unknown,
}

class EmailVerificationException implements Exception {
  final EmailVerificationErrorKind kind;
  final String message;
  final int? attemptsLeft;

  /// Seconds before another code may be asked for.
  final int? retryAfter;

  const EmailVerificationException(
    this.kind,
    this.message, {
    this.attemptsLeft,
    this.retryAfter,
  });

  /// Reads the server's answer: `{message, error_code, errors: {attempts_left
  /// | retry_after}}` from the verification endpoints, or the bare
  /// `{error: "Rate limit exceeded..."}` the per-address limiter sends.
  factory EmailVerificationException.fromResponse(int? status, Object? body) {
    String? message;
    String? code;
    Map<String, dynamic> errors = const {};
    if (body is Map) {
      message = body['message'] as String?;
      code = body['error_code'] as String?;
      final raw = body['errors'];
      if (raw is Map) errors = Map<String, dynamic>.from(raw);
    }
    int? number(String key) {
      final value = errors[key];
      if (value is int) return value;
      if (value is num) return value.ceil();
      return int.tryParse('${value ?? ''}');
    }

    switch (code) {
      case 'CODE_INVALID':
        final left = number('attempts_left');
        return EmailVerificationException(
          EmailVerificationErrorKind.wrongCode,
          message ??
              (left == null
                  ? "That code isn't right."
                  : "That code isn't right. $left ${left == 1 ? 'try' : 'tries'} left."),
          attemptsLeft: left,
        );
      case 'CODE_EXPIRED':
        return EmailVerificationException(
          EmailVerificationErrorKind.expired,
          message ?? 'That code has expired. Ask for a new one.',
          attemptsLeft: 0,
        );
      case 'CODE_LOCKED':
        return EmailVerificationException(
          EmailVerificationErrorKind.tooManyAttempts,
          message ?? 'Too many wrong tries. Ask for a new code.',
          attemptsLeft: 0,
        );
      case 'CODE_RECENTLY_SENT':
      case 'CODE_DAILY_LIMIT':
        return EmailVerificationException(
          EmailVerificationErrorKind.throttled,
          message ?? 'Please wait a little before asking for another code.',
          retryAfter: number('retry_after') ?? 60,
        );
      case 'ALREADY_VERIFIED':
        return EmailVerificationException(
          EmailVerificationErrorKind.alreadyVerified,
          message ?? 'Your email is already verified.',
        );
    }
    if (status == 429) {
      return const EmailVerificationException(
        EmailVerificationErrorKind.throttled,
        'Too many tries from this network. Wait a minute and try again.',
        retryAfter: 60,
      );
    }
    if (status == 401) {
      return const EmailVerificationException(
        EmailVerificationErrorKind.sessionExpired,
        'Your session has expired. Please sign in again.',
      );
    }
    return EmailVerificationException(
      EmailVerificationErrorKind.unknown,
      message ?? 'Something went wrong. Please try again.',
    );
  }

  factory EmailVerificationException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const EmailVerificationException(
          EmailVerificationErrorKind.network,
          'No connection. Check your internet and try again.',
        );
      default:
        return EmailVerificationException.fromResponse(
          error.response?.statusCode,
          error.response?.data,
        );
    }
  }

  @override
  String toString() => 'EmailVerificationException(${kind.name}): $message';
}

/// A code is on its way.
class EmailCodeSent {
  final String email;

  /// Seconds the code stays good.
  final int expiresIn;

  /// Seconds before another may be asked for.
  final int retryAfter;

  const EmailCodeSent({
    required this.email,
    required this.expiresIn,
    required this.retryAfter,
  });

  factory EmailCodeSent.fromJson(Map<String, dynamic> json) => EmailCodeSent(
        email: json['email'] as String? ?? '',
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 900,
        retryAfter: (json['retry_after'] as num?)?.toInt() ?? 60,
      );
}

/// The address is verified.
class EmailVerifiedResult {
  /// Whether tickets booked on the website under the address came in just now.
  final bool merged;

  /// How many registrations came in.
  final int registrationsTransferred;

  const EmailVerifiedResult({
    this.merged = false,
    this.registrationsTransferred = 0,
  });

  factory EmailVerifiedResult.fromJson(Map<String, dynamic> json) =>
      EmailVerifiedResult(
        merged: json['merged'] as bool? ?? false,
        registrationsTransferred:
            (json['registrations_transferred'] as num?)?.toInt() ?? 0,
      );
}

/// Sends and checks the code that proves an email/password account owns its
/// address. Signed-in calls: the account's own session token rides along
/// through the app's Dio stack.
///
/// Every failure is an [EmailVerificationException].
class EmailVerificationService {
  final Dio _dio;

  EmailVerificationService({Dio? dio}) : _dio = dio ?? APIService.instance.dio;

  Future<EmailCodeSent> sendCode() async {
    final response = await _call(() => _dio.post('/auth/email/send-code'));
    return EmailCodeSent.fromJson(_map(response.data));
  }

  Future<EmailVerifiedResult> verify(String code) async {
    final response = await _call(
      () => _dio.post('/auth/email/verify', data: {'code': code}),
    );
    return EmailVerifiedResult.fromJson(_map(response.data));
  }

  static Map<String, dynamic> _map(Object? data) =>
      data is Map ? Map<String, dynamic>.from(data) : const {};

  /// The session's access token can lapse while someone waits for the mail.
  /// The auth interceptor renews it on a 401 -- but not for paths under
  /// /auth/, these included -- so a 401 here renews it the way any other
  /// screen would, by loading the profile, and tries once more.
  Future<Response> _call(Future<Response> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        throw EmailVerificationException.fromDio(e);
      }
    }
    try {
      await _dio.get('/user/profile/me');
      return await request();
    } on DioException catch (e) {
      throw EmailVerificationException.fromDio(e);
    }
  }
}
