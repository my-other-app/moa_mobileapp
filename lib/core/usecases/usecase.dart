import 'package:myotherapp/core/error/either.dart';

/// Base class for all use cases.
///
/// Use cases represent a single action or business logic operation.
/// They follow the Command pattern.
///
/// Example:
/// ```dart
/// class GetUserUseCase extends UseCase<User, GetUserParams> {
///   @override
///   Future<Result<User>> call(GetUserParams params) async {
///     return await repository.getUser(params.id);
///   }
/// }
/// ```
abstract class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Use case that takes no parameters.
abstract class NoParamsUseCase<T> {
  Future<Result<T>> call();
}

/// Use case for stream-based operations.
abstract class StreamUseCase<T, Params> {
  Stream<Result<T>> call(Params params);
}

/// Empty params class for use cases that don't need parameters.
class NoParams {
  const NoParams();
}
