import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// Provider for the topics remote data source.
final topicRemoteDataSourceProvider = Provider<TopicRemoteDataSource>((ref) {
  return TopicRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// Where topics come from. Both routes are public and cached by the server
/// for five minutes (`app/api/interests/router.py`).
abstract class TopicRemoteDataSource {
  /// `GET /interests/list`: every topic with its interests -- icons, ids,
  /// order. On a server from before topics, one topic ("arts") holding all.
  Future<List<Topic>> getCatalogue();

  /// `GET /interests/topics`: topics with how many upcoming events and clubs
  /// each has. A server from before topics answers 404.
  Future<List<Topic>> getDirectory();
}

class TopicRemoteDataSourceImpl implements TopicRemoteDataSource {
  final Dio _dio;

  TopicRemoteDataSourceImpl(this._dio);

  @override
  Future<List<Topic>> getCatalogue() async {
    final response = await _dio.get<dynamic>('/interests/list');
    return TopicModel.listFromJson(response.data);
  }

  @override
  Future<List<Topic>> getDirectory() async {
    final response = await _dio.get<dynamic>('/interests/topics');
    return TopicModel.listFromJson(response.data);
  }
}
