import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Sends a GET once more when it could not reach the server at all.
///
/// A phone moving between Wi-Fi and mobile data drops the odd connection;
/// one quiet retry after a short pause turns most of those into a screen
/// that loads instead of an error. Only for reads:
///
/// - GET and HEAD only. A POST, PUT, PATCH or DELETE is never sent twice --
///   a registration, a payment or a vote must not happen twice because the
///   first answer was lost on the way back.
/// - Only when the connection failed (no answer at all). A 4xx or 5xx is an
///   answer; repeating it changes nothing.
/// - Once. The retry is marked and not retried again.
/// - Not a stream (the live room's), whose client reconnects on its own
///   clock, and not a request sent with [noRetryKey].
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.delay = const Duration(milliseconds: 700),
    Future<void> Function(Duration)? sleep,
    math.Random? random,
  })  : _sleep = sleep ?? Future<void>.delayed,
        _random = random ?? math.Random();

  final Dio _dio;

  /// The pause before the retry; up to half as much again is added at
  /// random, so many requests that failed together do not return together.
  final Duration delay;

  final Future<void> Function(Duration) _sleep;
  final math.Random _random;

  /// Set in a request's `extra` to send it once only.
  static const noRetryKey = 'noRetry';

  static const _retriedKey = 'networkRetried';

  /// Whether [error] means the server was never reached.
  static bool isConnectionFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return true;
      case DioExceptionType.unknown:
        return error.error is SocketException ||
            error.error is HttpException;
      default:
        return false;
    }
  }

  /// Whether a failed [options] may be sent again.
  static bool isRetryable(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return false;
    if (options.responseType == ResponseType.stream) return false;
    if (options.extra[noRetryKey] == true) return false;
    if (options.extra[_retriedKey] == true) return false;
    if (options.cancelToken?.isCancelled ?? false) return false;
    return true;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!isRetryable(options) || !isConnectionFailure(err)) {
      handler.next(err);
      return;
    }
    final jitter = delay.inMilliseconds == 0
        ? 0
        : _random.nextInt(delay.inMilliseconds ~/ 2 + 1);
    await _sleep(delay + Duration(milliseconds: jitter));
    if (options.cancelToken?.isCancelled ?? false) {
      handler.next(err);
      return;
    }
    debugPrint('RetryInterceptor: retrying ${options.path} once');
    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (e) {
      handler.next(DioException(requestOptions: options, error: e));
    }
  }
}
