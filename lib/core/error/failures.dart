import 'package:equatable/equatable.dart';

/// Base class for all domain failures.
///
/// Provides a consistent way to represent errors across the domain layer.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server-side failure (API errors, server unavailable, etc.)
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Network failure (no internet, timeout, etc.)
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Please check your internet connection',
    super.code,
  });
}

/// Cache failure (storage read/write errors)
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to access local storage',
    super.code,
  });
}

/// Authentication failure (invalid credentials, expired token, etc.)
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.code,
  });
}

/// Validation failure (invalid input data)
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code,
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Unknown/unexpected failure
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code,
  });
}
