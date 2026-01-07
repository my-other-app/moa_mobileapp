import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:myotherapp/core/config/env/env.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/core/secure_storage/token_model.dart';

enum DioMethod { post, get, put, delete }

class APIService {
  APIService._singleton();

  static final APIService instance = APIService._singleton();

  String get baseUrl => Env.apiBaseUrl;

  Future<Response> request(
    String endpoint,
    DioMethod method, {
    Map<String, dynamic>? param,
    String? contentType,
    formData,
    bool skipAuthToken = false,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final token = skipAuthToken
          ? TokenModel(accessToken: '', refreshToken: '')
          : await SecureStorage.instance.getAccessToken();

      /// TODO: Handle token expiration
      /// Use the intrecept in dio to refresh token if token is expired

      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: contentType ?? Headers.jsonContentType,
          headers: {
            if (!skipAuthToken)
              HttpHeaders.authorizationHeader: 'Bearer ${token.accessToken}',
            if (headers != null) ...headers,
          },
        ),
      );
      switch (method) {
        case DioMethod.post:
          return dio.post(
            endpoint,
            data: param ?? formData,
          );
        case DioMethod.get:
          return dio.get(
            endpoint,
            queryParameters: param,
          );
        case DioMethod.put:
          return dio.put(
            endpoint,
            data: param ?? formData,
          );
        case DioMethod.delete:
          return dio.delete(
            endpoint,
            data: param ?? formData,
          );
      }
    } catch (e) {
      debugPrint('Request failed 1111: $e');
      throw Exception('Request failed');
    }
  }
}
