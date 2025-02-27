import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/core/secure_storage/token_model.dart';

enum DioMethod { post, get, put, delete }

class APIService {
  APIService._singleton();

  static final APIService instance = APIService._singleton();

  String get baseUrl {
    if (kDebugMode) {
      return 'https://api.staging.myotherapp.com/api/v1';
    }

    // TODO : replace with Production url
    return 'https://api.staging.myotherapp.com/api/v1';
  }

  Future<Response> request(
    String endpoint,
    DioMethod method, {
    Map<String, dynamic>? param,
    String? contentType,
    formData,
    bool skipAuthToken = false,
  }) async {
    try {
      final token = skipAuthToken
          ? TokenModel(accessToken: '', refreshToken: '')
          : await SecureStorage.instance.getAccessToken();

      /// TODO: Handle token expiration
      /// TODO: Handle token refresh
      /// TODO: Handle token revocation

      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: contentType ?? Headers.jsonContentType,
          headers: {
            if (!skipAuthToken) HttpHeaders.authorizationHeader: 'Bearer ${token.accessToken}',
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
      debugPrint(e.toString());
      throw Exception('Request failed');
    }
  }
}
