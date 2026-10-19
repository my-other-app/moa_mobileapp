import 'package:flutter/material.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/network_status.dart';

/// [message], unless it is empty or reads like a stack trace rather than a
/// sentence ("DioException [connection error]: ...", "Instance of
/// 'TypeError'", "type 'Null' is not a subtype of ...") -- those are for logs.
@visibleForTesting
String? readableErrorMessage(String? message) {
  final text = message?.trim() ?? '';
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  const technical = [
    'exception',
    'instance of',
    'errno',
    'stack trace',
    "type '",
    'null check',
    'is not a subtype',
    '<html',
  ];
  if (technical.any(lower.contains)) return null;
  return text;
}

/// A reusable error view widget that displays an error message with a retry button.
///
/// This widget provides a consistent error UI across the app with:
/// - An appropriate icon based on error type
/// - A user-friendly error message
/// - A retry button
/// - Optional custom action button
///
/// A failure that is the network's -- no connection, or none fast enough --
/// is not an error the person can do anything about. It reads as the
/// offline state instead ([offlineTitle], [offlineMessage]): calm words, the
/// cloud rather than an alarm, and no need to keep tapping, because the
/// screen is read again by itself ([onRetry]) as soon as the app is back
/// online ([NetworkStatus.backOnline]). A screen with a saved copy never
/// gets here; this is for one never opened while online.
class ErrorView extends StatefulWidget {
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

  /// Whether the app can reach the server; defaults to
  /// [NetworkStatus.instance].
  final NetworkStatus? status;

  const ErrorView({
    super.key,
    this.message,
    this.exception,
    this.onRetry,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.status,
  });

  /// The offline state's words.
  static const offlineTitle = "You're offline";
  static const offlineMessage = "This page isn't saved on your phone yet. "
      "It will load by itself when you're back online.";
  static const slowTitle = 'The connection is slow';
  static const slowMessage = 'This page could not load in time. '
      "It will load by itself when you're back online, or try again now.";
  static const compactOfflineMessage =
      "You're offline. This will load when you're back online.";

  /// The offline state, for finding it in tests.
  static const offlineKey = ValueKey('error-view-offline');

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  late NetworkStatus _status;

  NetworkStatus _statusOf(ErrorView widget) =>
      widget.status ?? NetworkStatus.instance;

  void _listen(NetworkStatus status) {
    status.backOnline.addListener(_onBackOnline);
    status.offline.addListener(_onOfflineChanged);
  }

  void _stopListening(NetworkStatus status) {
    status.backOnline.removeListener(_onBackOnline);
    status.offline.removeListener(_onOfflineChanged);
  }

  @override
  void initState() {
    super.initState();
    _status = _statusOf(widget);
    _listen(_status);
  }

  @override
  void didUpdateWidget(ErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = _statusOf(widget);
    if (identical(status, _status)) return;
    _stopListening(_status);
    _status = status;
    _listen(_status);
  }

  @override
  void dispose() {
    _stopListening(_status);
    super.dispose();
  }

  /// Back online: read the screen again, if this failure was the network's.
  void _onBackOnline() {
    if (!mounted || !_networkFailure(_typeOf(widget))) return;
    widget.onRetry?.call();
  }

  /// Going offline can turn a failure that said nothing into the offline
  /// state.
  void _onOfflineChanged() {
    if (mounted) setState(() {});
  }

  ApiExceptionType _typeOf(ErrorView widget) =>
      widget.exception?.type ?? _detectErrorType(widget.message);

  /// The network's failure, not the server's or the app's: no connection,
  /// or no answer in time -- or a failure that says nothing more while the
  /// app knows it is offline.
  bool _networkFailure(ApiExceptionType type) =>
      type == ApiExceptionType.network ||
      type == ApiExceptionType.timeout ||
      (type == ApiExceptionType.unknown && _status.isOffline);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widget = this.widget;

    // Detect error type from message if no exception provided
    final errorType = _typeOf(widget);
    final offline = _networkFailure(errorType);
    final slow = errorType == ApiExceptionType.timeout;
    // The caller's message when it is written for people -- a repository's
    // "Couldn't load your blocked list." used to be replaced by the generic
    // "Something went wrong" -- and the friendly copy for the type when
    // there is none, or when it is a raw exception string. Offline, the
    // offline words: the caller's say what failed, these what happens next.
    final errorMessage = offline
        ? (slow ? ErrorView.slowMessage : ErrorView.offlineMessage)
        : widget.exception?.userMessage ??
            readableErrorMessage(widget.message) ??
            _getFriendlyMessage(errorType);

    if (widget.compact) {
      return _buildCompactError(
        context,
        offline ? ErrorView.compactOfflineMessage : errorMessage,
        theme,
        offline: offline,
      );
    }

    return Center(
      key: offline ? ErrorView.offlineKey : null,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            offline ? _buildOfflineIcon() : _buildErrorIcon(errorType),
            const SizedBox(height: 24),
            Text(
              offline
                  ? (slow ? ErrorView.slowTitle : ErrorView.offlineTitle)
                  : _getErrorTitle(errorType),
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
            if (widget.onRetry != null)
              offline
                  // It is read again by itself; the button is for the
                  // impatient, so it does not shout.
                  ? OutlinedButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    )
                  : FilledButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onAction,
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineIcon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(28),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey[600]),
    );
  }

  Widget _buildCompactError(
    BuildContext context,
    String message,
    ThemeData theme, {
    required bool offline,
  }) {
    return Container(
      key: offline ? ErrorView.offlineKey : null,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: offline ? Colors.grey.shade100 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: offline ? Colors.grey.shade300 : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.cloud_off_rounded : Icons.error_outline,
            color: offline ? Colors.grey.shade600 : Colors.red.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: offline ? Colors.grey.shade800 : Colors.red.shade900,
              ),
            ),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
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
        lowerMessage.contains('took too long') ||
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

  /// Get user-friendly message based on error type: the same copy
  /// [ApiException.userMessage] uses, so a screen reads the same whether it
  /// passed the exception or only a message.
  String _getFriendlyMessage(ApiExceptionType type) {
    switch (type) {
      case ApiExceptionType.network:
        return ApiException.networkMessage;
      case ApiExceptionType.timeout:
        return ApiException.timeoutMessage;
      case ApiExceptionType.server:
        return ApiException.serverErrorMessage;
      case ApiExceptionType.unauthorized:
        return ApiException.sessionEndedMessage;
      case ApiExceptionType.notFound:
        return 'The requested content was not found.';
      default:
        return ApiException.genericMessage;
    }
  }
}
