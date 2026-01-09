import 'package:flutter/material.dart';
import 'package:myotherapp/core/network/api_exception.dart';

/// A reusable error view widget that displays an error message with a retry button.
///
/// This widget provides a consistent error UI across the app with:
/// - An appropriate icon based on error type
/// - A user-friendly error message
/// - A retry button
/// - Optional custom action button
class ErrorView extends StatelessWidget {
  /// The error message to display
  final String? message;

  /// The API exception (if available) for richer error display
  final ApiException? exception;

  /// Callback when retry button is pressed
  final VoidCallback? onRetry;

  /// Optional custom action label
  final String? actionLabel;

  /// Optional custom action callback
  final VoidCallback? onAction;

  /// Whether to show a compact version
  final bool compact;

  const ErrorView({
    super.key,
    this.message,
    this.exception,
    this.onRetry,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Detect error type from message if no exception provided
    final errorType = exception?.type ?? _detectErrorType(message);
    final errorMessage =
        exception?.userMessage ?? _getFriendlyMessage(errorType);

    if (compact) {
      return _buildCompactError(context, errorMessage, theme);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildErrorIcon(errorType),
            const SizedBox(height: 24),
            Text(
              _getErrorTitle(errorType),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onRetry != null)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactError(
      BuildContext context, String message, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade900,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorIcon(ApiExceptionType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case ApiExceptionType.network:
      case ApiExceptionType.timeout:
        iconData = Icons.wifi_off_rounded;
        iconColor = Colors.orange;
        break;
      case ApiExceptionType.server:
        iconData = Icons.cloud_off_rounded;
        iconColor = Colors.red;
        break;
      case ApiExceptionType.unauthorized:
        iconData = Icons.lock_outline_rounded;
        iconColor = Colors.amber;
        break;
      case ApiExceptionType.notFound:
        iconData = Icons.search_off_rounded;
        iconColor = Colors.grey;
        break;
      default:
        iconData = Icons.error_outline_rounded;
        iconColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: iconColor.withAlpha((0.1 * 255).round()),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 64,
        color: iconColor,
      ),
    );
  }

  String _getErrorTitle(ApiExceptionType type) {
    switch (type) {
      case ApiExceptionType.network:
        return 'No Internet Connection';
      case ApiExceptionType.timeout:
        return 'Connection Timeout';
      case ApiExceptionType.server:
        return 'Server Error';
      case ApiExceptionType.unauthorized:
        return 'Session Expired';
      case ApiExceptionType.notFound:
        return 'Not Found';
      default:
        return 'Oops!';
    }
  }

  /// Detect error type from raw error message string
  ApiExceptionType _detectErrorType(String? message) {
    if (message == null) return ApiExceptionType.unknown;

    final lowerMessage = message.toLowerCase();

    // Check for network/connection errors
    if (lowerMessage.contains('socketexception') ||
        lowerMessage.contains('no internet') ||
        lowerMessage.contains('network is unreachable') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('failed host lookup')) {
      return ApiExceptionType.network;
    }

    // Check for timeout errors
    if (lowerMessage.contains('timeout') ||
        lowerMessage.contains('timed out') ||
        lowerMessage.contains('connection timeout')) {
      return ApiExceptionType.timeout;
    }

    // Check for server errors
    if (lowerMessage.contains('500') ||
        lowerMessage.contains('502') ||
        lowerMessage.contains('503') ||
        lowerMessage.contains('server error')) {
      return ApiExceptionType.server;
    }

    // Check for auth errors
    if (lowerMessage.contains('401') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('unauthenticated')) {
      return ApiExceptionType.unauthorized;
    }

    // Check for not found errors
    if (lowerMessage.contains('404') || lowerMessage.contains('not found')) {
      return ApiExceptionType.notFound;
    }

    return ApiExceptionType.unknown;
  }

  /// Get user-friendly message based on error type
  String _getFriendlyMessage(ApiExceptionType type) {
    switch (type) {
      case ApiExceptionType.network:
        return 'Please check your internet connection and try again.';
      case ApiExceptionType.timeout:
        return 'The connection is taking too long. Please try again.';
      case ApiExceptionType.server:
        return 'Something went wrong on our end. Please try again later.';
      case ApiExceptionType.unauthorized:
        return 'Your session has expired. Please log in again.';
      case ApiExceptionType.notFound:
        return 'The requested content was not found.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
