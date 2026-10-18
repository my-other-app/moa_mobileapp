import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// Topics: the main categories interests sit under.
abstract class TopicRepository {
  /// Every topic with its interests (`/interests/list`), in order.
  Future<Result<List<Topic>>> getCatalogue();

  /// Topics with live counts (`/interests/topics`). Fails on a server that
  /// does not have it yet -- the caller falls back to [getCatalogue].
  Future<Result<List<Topic>>> getDirectory();
}
