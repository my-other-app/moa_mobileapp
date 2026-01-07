import 'package:myotherapp/core/error/failures.dart';

/// A value that represents either a success or a failure.
///
/// This is used throughout the domain layer to handle operations
/// that can fail without throwing exceptions.
///
/// Example:
/// ```dart
/// final result = await userRepository.getUser(id);
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (user) => print('User: ${user.name}'),
/// );
/// ```
class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isLeft;

  const Either._({L? left, R? right, required bool isLeft})
      : _left = left,
        _right = right,
        _isLeft = isLeft;

  /// Creates a Left (failure) value.
  factory Either.left(L value) => Either._(left: value, isLeft: true);

  /// Creates a Right (success) value.
  factory Either.right(R value) => Either._(right: value, isLeft: false);

  /// Returns true if this is a Left (failure) value.
  bool get isLeft => _isLeft;

  /// Returns true if this is a Right (success) value.
  bool get isRight => !_isLeft;

  /// Gets the left value or throws if this is a Right.
  L get left {
    if (!_isLeft) throw StateError('Cannot get left value from Right');
    return _left as L;
  }

  /// Gets the right value or throws if this is a Left.
  R get right {
    if (_isLeft) throw StateError('Cannot get right value from Left');
    return _right as R;
  }

  /// Pattern matching on Either.
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    if (_isLeft) {
      return onLeft(_left as L);
    }
    return onRight(_right as R);
  }

  /// Maps the right value.
  Either<L, T> map<T>(T Function(R right) mapper) {
    if (_isLeft) {
      return Either.left(_left as L);
    }
    return Either.right(mapper(_right as R));
  }

  /// Returns the right value or a default.
  R getOrElse(R Function() orElse) {
    if (_isLeft) return orElse();
    return _right as R;
  }

  /// Returns the right value or null.
  R? getOrNull() => _isLeft ? null : _right;
}

/// Type alias for common Either with Failure.
typedef Result<T> = Either<Failure, T>;
