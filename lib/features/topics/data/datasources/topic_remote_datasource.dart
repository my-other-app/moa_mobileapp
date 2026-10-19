import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// Provider for the topics remote data source.
final topicRemoteDataSourceProvider = Provider<TopicRemoteDataSource>((ref) {
  return TopicRemoteDataSourceImpl(
    ref.watch(dioProvider),
    cache: ref.watch(apiCacheProvider),
  );
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

  /// The last catalogue saved on this phone, or null. No network.
  Future<List<Topic>?> savedCatalogue();

  /// The last directory saved on this phone, or null. No network.
  Future<List<Topic>?> savedDirectory();
}

class TopicRemoteDataSourceImpl implements TopicRemoteDataSource {
  final Dio _dio;
  final ApiCache? _cache;

  TopicRemoteDataSourceImpl(this._dio, {ApiCache? cache}) : _cache = cache;

  ApiCache get _saved => _cache ?? ApiCache.instance;

  static const _catalogue = '/interests/list';
  static const _directory = '/interests/topics';

  /// The same for everyone: saved as plain files, revalidated by ETag.
  static Options get _policy => Options(extra: CachePolicy.shared.extra);

  @override
  Future<List<Topic>> getCatalogue() async {
    final response = await _dio.get<dynamic>(_catalogue, options: _policy);
    return TopicModel.listFromJson(response.data);
  }

  @override
  Future<List<Topic>> getDirectory() async {
    final response = await _dio.get<dynamic>(_directory, options: _policy);
    return TopicModel.listFromJson(response.data);
  }

  @override
  Future<List<Topic>?> savedCatalogue() => _read(_catalogue);

  @override
  Future<List<Topic>?> savedDirectory() => _read(_directory);

  Future<List<Topic>?> _read(String path) async {
    final data = await _saved.savedAnswer(_dio, path);
    if (data == null) return null;
    final topics = TopicModel.listFromJson(data);
    return topics.isEmpty ? null : topics;
  }
}
