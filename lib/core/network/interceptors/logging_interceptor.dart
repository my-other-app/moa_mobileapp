import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logging interceptor for debugging API requests and responses.
///
/// Only active in debug mode. Logs:
/// - Request method, URL, headers, and body
/// - Response status, headers, and body
/// - Errors with details
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌──────────────────────────────────────────────────────────');
    debugPrint('│ 🌐 REQUEST');
    debugPrint('├──────────────────────────────────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    debugPrint('│ Headers: ${_prettyJson(options.headers)}');
    if (options.data != null) {
      debugPrint('│ Body: ${_prettyJson(options.data)}');
    }
    debugPrint('└──────────────────────────────────────────────────────────');

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('┌──────────────────────────────────────────────────────────');
    debugPrint('│ ✅ RESPONSE');
    debugPrint('├──────────────────────────────────────────────────────────');
    debugPrint('│ ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('│ Data: ${_prettyJson(response.data)}');
    debugPrint('└──────────────────────────────────────────────────────────');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌──────────────────────────────────────────────────────────');
    debugPrint('│ ❌ ERROR');
    debugPrint('├──────────────────────────────────────────────────────────');
    debugPrint('│ ${err.type}');
    debugPrint('│ ${err.requestOptions.uri}');
    debugPrint('│ Message: ${err.message}');
    if (err.response != null) {
      debugPrint('│ Response: ${_prettyJson(err.response?.data)}');
    }
    debugPrint('└──────────────────────────────────────────────────────────');

    handler.next(err);
  }

  String _prettyJson(dynamic json) {
    try {
      if (json == null) return 'null';
      if (json is String) return json;
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      return json.toString();
    }
  }
}
