import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/topics/data/datasources/topic_remote_datasource.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/repositories/topic_repository.dart';

/// Provider for the topics repository.
final topicRepositoryProvider = Provider<TopicRepository>((ref) {
  return TopicRepositoryImpl(
    remoteDataSource: ref.watch(topicRemoteDataSourceProvider),
  );
});

class TopicRepositoryImpl implements TopicRepository {
  final TopicRemoteDataSource remoteDataSource;

  TopicRepositoryImpl({required this.remoteDataSource});

  Future<Result<List<Topic>>> _guard(
      String name, Future<List<Topic>> Function() call) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('TopicRepository.$name error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<Topic>>> getCatalogue() =>
      _guard('getCatalogue', remoteDataSource.getCatalogue);

  @override
  Future<Result<List<Topic>>> getDirectory() =>
      _guard('getDirectory', remoteDataSource.getDirectory);

  @override
  Future<List<Topic>?> savedCatalogue() => remoteDataSource.savedCatalogue();

  @override
  Future<List<Topic>?> savedDirectory() => remoteDataSource.savedDirectory();
}
