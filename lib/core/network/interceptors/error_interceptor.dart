import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:finnet/core/network/api_exception.dart';

/// Interceptor for consistent error handling across all API requests.
///
/// Reads every failure into an [ApiException] and passes it on inside the
/// [DioException]'s `error` -- the only thing an error handler may pass
/// along. [APIService.request] unwraps it; anything calling Dio directly gets
/// the [DioException], which `extractErrorMessage` and `mapErrorToFailure`
/// both understand.
///
/// The server's own words are kept for every 4xx it explains, 401, 403 and
/// 404 included: they used to be replaced with stock copy, which told a door
/// volunteer refused by the check-in endpoint to "log in again".
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Already read -- by AuthInterceptor when it ended the session, or by an
    // earlier pass when a retried request failed again. Reading it a second
    // time would replace its words with the response's.
    if (err.error is ApiException) {
      handler.next(err);
      return;
    }

    final apiException = ApiException.fromDioException(err);

    debugPrint('ErrorInterceptor: $apiException');

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
        message: err.message,
      ),
    );
  }
}
