import 'dart:io';

import 'package:dio/dio.dart';

/// Types of API exceptions for categorizing errors.
enum ApiExceptionType {
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  server,
  cancelled,
  unknown,
}

/// Custom exception class for API errors.
///
/// Provides consistent error handling across the application. Build one with
/// [ApiException.fromResponse] or [ApiException.fromDioException] so every
/// error is read the same way; [userMessage] is what to show a person.
class ApiException implements Exception {
  /// What went wrong, already fit to show: the server's own words for a 4xx
  /// when it sent any, otherwise stock copy for the status. Never a class
  /// name or a status code.
  final String message;
  final int? statusCode;
  final ApiExceptionType type;
  final dynamic originalError;

  /// What the server actually said, when it said anything.
  ///
  /// Kept apart from [message] because a 5xx's words are replaced with
  /// friendly copy (see [userMessage]), and because some callers classify on
  /// the exact prose -- the volunteer check-in endpoint answers 401 "User is
  /// not a volunteer for this event", which must reach the door volunteer as
  /// that and not as "please sign in again".
  final String? serverMessage;

  /// The `error_code` from the backend's error envelope, when set
  /// (`ACCOUNT_SUSPENDED`, `TOTP_REQUIRED`, `UPDATE_APP_TO_PAY`...).
  ///
  /// Branch on this rather than on [message]: codes are stable, prose is not.
  final String? errorCode;

  /// The envelope's `errors` object: field errors for a validation failure,
  /// or extra data such as `web_url` for UPDATE_APP_TO_PAY.
  final Map<String, dynamic>? errors;

  /// Per-field errors, by field name, for a form to show beside its fields.
  ///
  /// Older responses -- the register endpoint's among them -- send these as
  /// a map in `message` itself rather than a string; newer ones send a
  /// string `message` with the details in `errors`. Both land here, the
  /// `message` map's entries first. Null when there are none.
  final Map<String, dynamic>? fieldErrors;

  /// The envelope's `track_id`, set on unhandled server errors so a report
  /// can be matched with the server's log.
  final String? trackId;

  const ApiException({
    required this.message,
    this.statusCode,
    this.type = ApiExceptionType.unknown,
    this.originalError,
    this.serverMessage,
    this.errorCode,
    this.errors,
    this.fieldErrors,
    this.trackId,
  });

  /// Copy for an error nothing more specific can be said about.
  static const String genericMessage = 'Something went wrong. Please try again.';
  static const String networkMessage =
      'No internet connection. Please check your network and try again.';
  static const String timeoutMessage =
      'That took too long. Please check your connection and try again.';
  static const String serverErrorMessage =
      'Something went wrong on our side. Please try again in a moment.';
  static const String cancelledMessage = 'The request was cancelled.';
  static const String sessionEndedMessage =
      'Your session has ended. Please sign in again.';
  static const String accountSuspendedMessage =
      'This account has been suspended. If you think this is a mistake, '
      'write to support@myotherapp.in.';

  /// Read a non-2xx answer from the backend.
  ///
  /// The envelope is `{message, errors, error_code, track_id}`; older routes
  /// still answer FastAPI's `{"detail": ...}`, and the rate limiter answers
  /// `{"error": "Rate limit exceeded: ..."}`. All three are understood.
  factory ApiException.fromResponse(int? statusCode, Object? body,
      {Object? originalError}) {
    final envelope = _Envelope.parse(body);
    final type = typeForStatus(statusCode);

    return ApiException(
      message: _messageFor(statusCode, type, envelope),
      statusCode: statusCode,
      type: type,
      originalError: originalError,
      serverMessage: envelope.message,
      errorCode: envelope.errorCode,
      errors: envelope.errors,
      fieldErrors: envelope.fieldErrors,
      trackId: envelope.trackId,
    );
  }

  /// Read whatever Dio threw, whether or not a response came back.
  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // Dio 5.10+: reading the body took longer than a transform timeout.
      case DioExceptionType.transformTimeout:
        return ApiException(
          message: timeoutMessage,
          type: ApiExceptionType.timeout,
          originalError: error,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: networkMessage,
          type: ApiExceptionType.network,
          originalError: error,
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          message: "We couldn't make a secure connection. Please try again.",
          type: ApiExceptionType.network,
          originalError: error,
        );
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(
          error.response?.statusCode,
          error.response?.data,
          originalError: error,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: cancelledMessage,
          type: ApiExceptionType.cancelled,
          originalError: error,
        );
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner is SocketException || inner is HttpException) {
          return ApiException(
            message: networkMessage,
            type: ApiExceptionType.network,
            originalError: error,
          );
        }
        return ApiException(
          message: genericMessage,
          type: ApiExceptionType.unknown,
          originalError: error,
        );
    }
  }

  /// The kind of failure an HTTP status means.
  static ApiExceptionType typeForStatus(int? statusCode) {
    if (statusCode == null) return ApiExceptionType.unknown;
    if (statusCode >= 500) return ApiExceptionType.server;
    switch (statusCode) {
      case 400:
      case 422:
        return ApiExceptionType.badRequest;
      case 401:
        return ApiExceptionType.unauthorized;
      case 403:
        return ApiExceptionType.forbidden;
      case 404:
        return ApiExceptionType.notFound;
      default:
        return ApiExceptionType.unknown;
    }
  }

  static String _messageFor(
      int? statusCode, ApiExceptionType type, _Envelope envelope) {
    // A 5xx's words are shown only when the server raised it on purpose,
    // with a code -- a club's payment gateway being unavailable, say.
    // Without one it is the catch-all "Internal Server Error", or an
    // exception's own text ("Failed to create order: <error>"), and neither
    // helps anyone.
    if (type == ApiExceptionType.server) {
      return envelope.errorCode != null && envelope.message != null
          ? envelope.message!
          : serverErrorMessage;
    }
    // The limiter's own answer is "Rate limit exceeded: 20 per 1 minute";
    // a coded 429 (LOGIN_LOCKED) says how long to wait, so that one is kept.
    if (statusCode == 429 && envelope.errorCode == null) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    return envelope.message ?? _stockCopy(type);
  }

  static String _stockCopy(ApiExceptionType type) {
    switch (type) {
      case ApiExceptionType.unauthorized:
        return sessionEndedMessage;
      case ApiExceptionType.forbidden:
        return "You don't have permission to do that.";
      case ApiExceptionType.notFound:
        return "We couldn't find that. It may have been removed.";
      case ApiExceptionType.network:
        return networkMessage;
      case ApiExceptionType.timeout:
        return timeoutMessage;
      case ApiExceptionType.server:
        return serverErrorMessage;
      case ApiExceptionType.cancelled:
        return cancelledMessage;
      case ApiExceptionType.badRequest:
      case ApiExceptionType.unknown:
        return genericMessage;
    }
  }

  /// For logs and crash reports only -- never put this in front of a person;
  /// use [userMessage].
  @override
  String toString() => 'ApiException: $message (${type.name}, code: $statusCode'
      '${errorCode == null ? '' : ', error_code: $errorCode'})';

  /// Whether this error is due to authentication issues.
  bool get isAuthError => type == ApiExceptionType.unauthorized;

  /// Whether this error is due to network issues.
  bool get isNetworkError =>
      type == ApiExceptionType.network || type == ApiExceptionType.timeout;

  /// Whether this error is a server-side error.
  bool get isServerError => type == ApiExceptionType.server;

  /// What to show a person.
  ///
  /// The server's message where there is one (see [message]); friendly copy
  /// for a dropped connection, a timeout or a 5xx; a clearer sentence for the
  /// few codes any screen can meet. Never a class name or a status code.
  String get userMessage {
    switch (type) {
      case ApiExceptionType.network:
        return networkMessage;
      case ApiExceptionType.timeout:
        return timeoutMessage;
      case ApiExceptionType.cancelled:
        return cancelledMessage;
      case ApiExceptionType.server:
        return errorCode != null && _isUsable(serverMessage)
            ? serverMessage!
            : serverErrorMessage;
      case ApiExceptionType.badRequest:
      case ApiExceptionType.unauthorized:
      case ApiExceptionType.forbidden:
      case ApiExceptionType.notFound:
      case ApiExceptionType.unknown:
        final known = _copyForCode[errorCode];
        if (known != null) return known;
        return _isUsable(message) ? message : _stockCopy(type);
    }
  }

  /// Codes any request can meet, worded for the person who meets them.
  /// Codes only one flow can meet are worded by that flow (sign-in has its
  /// own, `signInErrorMessage`).
  static const Map<String, String> _copyForCode = {
    'ACCOUNT_SUSPENDED': accountSuspendedMessage,
    'TOKEN_EXPIRED': sessionEndedMessage,
    // The refresh token was used from two places, so the server ended the
    // session. To the person it is the same as any other ended session.
    'SESSION_REUSED': sessionEndedMessage,
  };

  static bool _isUsable(String? text) => text != null && text.trim().isNotEmpty;
}

/// The parts of an error body worth reading.
class _Envelope {
  const _Envelope({
    this.message,
    this.errorCode,
    this.errors,
    this.fieldErrors,
    this.trackId,
  });

  final String? message;
  final String? errorCode;
  final Map<String, dynamic>? errors;
  final Map<String, dynamic>? fieldErrors;
  final String? trackId;

  static const _generic = {'invalid request', 'bad request'};

  static _Envelope parse(Object? body) {
    if (body is! Map) return const _Envelope();

    final rawErrors = body['errors'];
    final errors =
        rawErrors is Map ? Map<String, dynamic>.from(rawErrors) : null;

    // `message` is read only when it is a string. Older responses put the
    // field errors there as a map, and reading that `as String?` threw
    // inside the interceptor, so those errors never reached the screen.
    final rawMessage = body['message'];
    final messageFields =
        rawMessage is Map ? Map<String, dynamic>.from(rawMessage) : null;
    final fieldErrors = (messageFields == null && errors == null)
        ? null
        : <String, dynamic>{...?errors, ...?messageFields};

    String? message = _text(rawMessage) ??
        _fromDetail(body['detail']) ??
        _text(body['error']);

    // "Invalid request" says nothing a person can act on; the field error
    // under it does ("email already exists" from /user/register).
    if (message == null || _generic.contains(message.toLowerCase())) {
      message = _firstFieldError(messageFields) ??
          _firstFieldError(errors) ??
          message;
    }

    return _Envelope(
      message: message,
      errorCode: _text(body['error_code']),
      errors: errors,
      fieldErrors: fieldErrors,
      trackId: _text(body['track_id']),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// FastAPI's `detail`: a string, or a list of `{loc, msg, type}`.
  static String? _fromDetail(Object? detail) {
    if (detail is String) return _text(detail);
    if (detail is List) {
      for (final item in detail) {
        if (item is Map) {
          final msg = item['msg'];
          if (msg is String) {
            final sentence = _sentence(msg);
            if (sentence != null) return sentence;
          }
        }
      }
    }
    if (detail is Map) return _text(detail['message']);
    return null;
  }

  static String? _firstFieldError(Object? errors) {
    if (errors is String) return _sentence(errors);
    if (errors is Map) {
      for (final value in errors.values) {
        final found = _firstFieldError(value);
        if (found != null) return found;
      }
    }
    if (errors is List) {
      for (final value in errors) {
        final found = _firstFieldError(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Pydantic prefixes a custom validator's words with "Value error, ".
  static String? _sentence(String raw) {
    var text = raw.trim();
    if (text.startsWith('Value error, ')) {
      text = text.substring('Value error, '.length).trim();
    }
    if (text.isEmpty) return null;
    return text[0].toUpperCase() + text.substring(1);
  }
}
