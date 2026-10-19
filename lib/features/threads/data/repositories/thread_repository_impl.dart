import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/threads/data/datasources/thread_remote_datasource.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';

/// Provider for the threads repository.
final threadRepositoryProvider = Provider<ThreadRepository>((ref) {
  return ThreadRepositoryImpl(
    remoteDataSource: ref.watch(threadRemoteDataSourceProvider),
  );
});

/// Turn whatever a call threw into a [Failure] a person can read.
///
/// The kind and code come from [mapErrorToFailure] -- a removed post must
/// still be told apart by its '404', an expired session by being an
/// [AuthFailure]. The words come from [extractErrorMessage], which reads the
/// server's own `message` ("Write something first", "That option is not on
/// this poll") where [mapErrorToFailure] would substitute generic copy.
///
/// Shared with the moderation repository, whose callers branch on the same
/// codes -- a '429' for a rate-limited report among them.
Failure threadFailureFrom(Object error) {
  final mapped = mapErrorToFailure(error);
  // Only a transport error has a server message to prefer. Anything else --
  // a parse slip -- keeps the mapped message, not a Dart type error.
  final message = error is DioException
      ? extractErrorMessage(error, defaultMessage: mapped.message)
      : mapped.message;
  // The HTTP status, where the mapper did not already set a code: it files
  // 401 and 403 alike under AuthFailure, and only a 401 means "sign in".
  final status = error is DioException ? error.response?.statusCode : null;
  final code = mapped.code ?? status?.toString();

  if (mapped is NetworkFailure) {
    return NetworkFailure(message: message, code: code);
  }
  if (mapped is AuthFailure) {
    return AuthFailure(message: message, code: code);
  }
  if (mapped is ValidationFailure) {
    return ValidationFailure(message: message, code: code);
  }
  if (mapped is ServerFailure) {
    return ServerFailure(message: message, code: code);
  }
  return UnknownFailure(message: message, code: code);
}

/// Implementation of [ThreadRepository].
class ThreadRepositoryImpl implements ThreadRepository {
  final ThreadRemoteDataSource remoteDataSource;

  ThreadRepositoryImpl({required this.remoteDataSource});

  Future<Result<T>> _guard<T>(String name, Future<T> Function() call) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('ThreadRepository.$name error: $e');
      return Either.left(threadFailureFrom(e));
    }
  }

  @override
  Future<Result<ThreadPage>> getClubThreads(
    int clubId, {
    int offset = 0,
    int limit = 20,
  }) {
    return _guard('getClubThreads', () async {
      final page = await remoteDataSource.getClubThreads(
        clubId,
        offset: offset,
        limit: limit,
      );
      return page.toEntity(requestedOffset: offset, requestedLimit: limit);
    });
  }

  @override
  Future<Result<ThreadPage>> getFollowingFeed({
    String? after,
    int limit = 20,
  }) {
    return _guard('getFollowingFeed', () async {
      final page =
          await remoteDataSource.getFollowingFeed(after: after, limit: limit);
      return page.toEntity(requestedOffset: 0, requestedLimit: limit);
    });
  }

  @override
  Future<ThreadPage?> savedFollowingFeed({int limit = 20}) async {
    try {
      final page = await remoteDataSource.savedFollowingFeed(limit: limit);
      return page?.toEntity(requestedOffset: 0, requestedLimit: limit);
    } catch (e) {
      debugPrint('ThreadRepository.savedFollowingFeed: $e');
      return null;
    }
  }

  @override
  Future<Result<Thread>> getThread(String threadId) async {
    final result = await _guard('getThread', () async {
      return (await remoteDataSource.getThread(threadId)).toEntity();
    });
    if (result.isRight && result.right.id.isEmpty) {
      // A 200 with no post in it is as good as gone, and reported the way
      // the server reports a removed one.
      return Either.left(
        const ServerFailure(message: 'Post not found', code: '404'),
      );
    }
    return result;
  }

  @override
  Future<Result<LikeResult>> toggleLike(String threadId) {
    return _guard('toggleLike', () async {
      return (await remoteDataSource.toggleLike(threadId)).toEntity();
    });
  }

  @override
  Future<Result<Poll>> vote(String threadId, String optionId) {
    return _guard('vote', () async {
      return (await remoteDataSource.vote(threadId, optionId)).toEntity();
    });
  }

  @override
  Future<Result<List<ThreadComment>>> getComments(String threadId) {
    return _guard('getComments', () async {
      final comments = await remoteDataSource.getComments(threadId);
      return comments.map((c) => c.toEntity()).toList();
    });
  }

  @override
  Future<Result<ThreadComment>> addComment(String threadId, String body) {
    return _guard('addComment', () async {
      return (await remoteDataSource.addComment(threadId, body)).toEntity();
    });
  }

  @override
  Future<Result<void>> deleteComment(String threadId, String commentId) {
    return _guard('deleteComment', () async {
      await remoteDataSource.deleteComment(threadId, commentId);
    });
  }
}
