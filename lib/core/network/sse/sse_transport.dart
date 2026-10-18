import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// What the server answered when a stream was opened: its status and
/// headers, and the body still arriving.
///
/// Every answer comes back as one of these, a 404 or a 503 included: for a
/// stream those mean "poll instead", which is the caller's to decide, not an
/// error to report. Only a failure to get an answer at all (no network, the
/// open aborted) is thrown.
class SseResponse {
  SseResponse({
    required this.statusCode,
    Map<String, List<String>> headers = const {},
    required this.body,
    void Function()? onClose,
  })  : headers = {
          for (final e in headers.entries) e.key.toLowerCase(): e.value,
        },
        _onClose = onClose;

  final int statusCode;

  /// Header names lower-cased.
  final Map<String, List<String>> headers;

  /// The body as it arrives. It can be listened to once.
  final Stream<List<int>> body;

  final void Function()? _onClose;
  bool _closed = false;

  String? header(String name) {
    final values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// A 2xx that really is a stream. A 2xx of anything else is an older
  /// server (or a proxy) answering a route it does not have.
  bool get isEventStream =>
      isSuccess &&
      (header('content-type') ?? '')
          .trimLeft()
          .toLowerCase()
          .startsWith('text/event-stream');

  /// `Retry-After` in seconds; null when it is absent or not a number.
  Duration? get retryAfter {
    final seconds = int.tryParse((header('retry-after') ?? '').trim());
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  /// The `error_code` of a refusal's JSON body (`LIVE_STREAM_FULL`, ...), or
  /// null. Reads the body -- at most 16 KB, for at most [timeout] -- and
  /// closes the response.
  Future<String?> readErrorCode({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final bytes = <int>[];
      await for (final chunk in body.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 16 * 1024) break;
      }
      final json = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      final code = json is Map ? json['error_code'] : null;
      return code is String ? code : null;
    } catch (_) {
      return null;
    } finally {
      close();
    }
  }

  /// Lets go of the connection. Safe to call more than once.
  void close() {
    if (_closed) return;
    _closed = true;
    _onClose?.call();
  }
}

/// Opens a server-sent-events stream.
abstract class SseTransport {
  /// GETs [path] as a stream. The open, and the stream after it, end when
  /// [abort] completes or the response is closed.
  Future<SseResponse> open(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String> headers = const {},
    Future<void>? abort,
  });
}

/// [SseTransport] over the app's one Dio, so a stream is sent exactly as
/// the poll it replaces: the same base URL and the same interceptors -- the
/// signed-in person's token included.
class DioSseTransport implements SseTransport {
  DioSseTransport(this._dio);

  final Dio _dio;

  @override
  Future<SseResponse> open(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String> headers = const {},
    Future<void>? abort,
  }) async {
    final cancel = CancelToken();
    void stop() {
      if (!cancel.isCancelled) cancel.cancel('stream closed by the app');
    }

    abort?.then((_) => stop(), onError: (Object _) => stop());

    final response = await _dio.get<ResponseBody>(
      path,
      queryParameters: query,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        // The client's own clocks decide when a stream is dead (no frame
        // 20 s after opening, or 45 s of silence after). Dio's 30 s would
        // cut a healthy stream whose pings were late, and wait 30 s for
        // headers the client gives up on sooner.
        receiveTimeout: Duration.zero,
        // Every status is the caller's to read: a 404 here means "poll as
        // before" -- not an error for the interceptors to log to analytics,
        // or a 401 to spend the refresh token on.
        validateStatus: (_) => true,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          ...headers,
        },
      ),
    );
    return SseResponse(
      statusCode: response.statusCode ?? 0,
      headers: response.headers.map,
      body: response.data?.stream ?? const Stream<List<int>>.empty(),
      onClose: stop,
    );
  }
}
