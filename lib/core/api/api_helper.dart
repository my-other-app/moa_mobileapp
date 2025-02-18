import 'dart:io';
import 'package:dio/dio.dart';
import 'package:myotherapp/core/api/api_execptions.dart';

//TO-DO: Replace this with your actual base URL
const String baseUrl = "apibaseURLComesHere";

enum Method { get, post, put, patch, delete }

class Api {
  final Dio _dio;
  const Api(this._dio);

  Future<Map<String, dynamic>> execute({
    required Method method,
    required String url,
    dynamic data,
  }) async {
    try {
      final methodMap = {
        Method.get: () => _dio.get(url),
        Method.post: () => _dio.post(url, data: data),
        Method.put: () => _dio.put(url, data: data),
        Method.patch: () => _dio.patch(url, data: data),
        Method.delete: () => _dio.delete(url, data: data),
      };

      final response = await methodMap[method]!();
      return _returnResponse(response);
    } on SocketException {
      throw FetchDataException('No Internet connection');
    } on DioException catch (e) {
      return _returnResponse(e.response!);
    }
  }

   Map<String, dynamic> _returnResponse(Response response) {
     final statusCodeActions = {
       200: () => response.data,
       201: () => response.data,
       400: () => throw BadRequestException(response.data["message"].toString()),
       401: () => throw UnauthorizedException(response.data["message"].toString()),
       403: () => throw ForbiddenException(response.data["message"].toString()),
       404: () => throw NotFoundException(response.data["message"].toString()),
       422: () => throw UnprocessableContentException(response.data["message"].toString()),
       500: () => throw InternalServerException(response.data["message"].toString()),
     };
   
     if (statusCodeActions.containsKey(response.statusCode)) {
       return statusCodeActions[response.statusCode]!();
     } else {
       throw FetchDataException(
         'Request failed with StatusCode : ${response.statusCode}'
       );
     }
   }
}
