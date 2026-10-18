import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:finnet/core/network/sse/sse_frame.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';

/// Opens the view's stream, sending [lastEventId] (when there is one) as
/// `Last-Event-ID`. The open, and the stream, end when [abort] completes.
typedef LiveStreamOpener = Future<SseResponse> Function({
  String? lastEventId,
  required Future<void> abort,
});

/// The view's poll: what it shows now, or null for a body it cannot read.
/// Throws when the poll fails.
typedef LivePoller<T> = Future<T?> Function();

/// What a [LiveStreamClient] is doing.
enum LiveMode {
  /// Not started.
  idle,

  /// Opening the stream; nothing has come down it yet.
  connecting,

  /// A snapshot or a ping has come down the stream: it is the source.
  streaming,

  /// Waiting to open the stream again.
  reconnecting,

  /// The stream is unavailable for now: polling, and trying the stream
  /// again later.
  polling,

  /// The server has no stream (404, 405, 501, a 2xx that is not a stream):
  /// the page does what it did before streams, and tries the stream again
  /// once, ten minutes on.
  off,

  /// The stream said the room is not there any more. Not reopened.
  gone,

  /// Closed because the app was in the background.
  paused,

  /// Closed for good: the page went away.
  closed,
}

/// Keeps one view of an event's live room current: from the server's stream
/// (`GET /events/{id}/live/stream?view=...`) when it has one, from the view's
/// poll when it does not, as the live room's stream contract (LIVE_SSE)
/// asks of every client:
///
/// - Every `snapshot` is the poll's own body, parsed with the poll's parser
///   and handed to [onData]; its `id` is sent back as `Last-Event-ID` on every
///   reconnect, so a stream that missed nothing sends no snapshot again.
/// - `retry:` sets the reconnect delay: that, then doubled for each failure
///   in a row up to 30 s, each with 0-100 % jitter added.
/// - An open that gets no snapshot or ping within 20 s has failed; a stream
///   silent for 45 s (three missed pings) is dropped and reopened.
/// - Polls instead -- the view's poll, as before streams -- when the server
///   has no stream (404/405/501/422, or a 2xx that is not one: tried once
///   more after 10 minutes), when it is full (503 `LIVE_STREAM_FULL`, or
///   429: tried again after `Retry-After`, 60 s without one), or after three
///   failed attempts in a row (tried again after 5 minutes).
/// - `gone`: closed and not reopened; one poll says what the page shows now.
/// - In the background: closed after [hiddenGrace], reopened (with the last
///   id) when the app is back.
///
/// There is never more than one stream open or one poll in flight, and
/// [close] leaves no timer running.
class LiveStreamClient<T> {
  LiveStreamClient({
    required LiveStreamOpener open,
    required LivePoller<T> poll,
    required T? Function(Object? json) parse,
    required void Function(T value) onData,
    this.pollEvery,
    Random? random,
  })  : _open = open,
        _poll = poll,
        _parse = parse,
        _onData = onData,
        _random = random ?? Random();

  /// The reconnect delay until the stream's own `retry:` arrives.
  static const defaultRetry = Duration(seconds: 3);

  /// Doubling the reconnect delay stops here (before jitter).
  static const maxBackoff = Duration(seconds: 30);

  /// An open with no snapshot or ping by now has failed.
  static const openDeadline = Duration(seconds: 20);

  /// Three missed pings: the stream is dead even if the socket is not.
  static const silenceLimit = Duration(seconds: 45);

  /// Failed attempts in a row before falling back to the poll.
  static const failuresBeforePolling = 3;

  /// After those failures, the stream is tried again this much later.
  static const retryAfterFailures = Duration(minutes: 5);

  /// A server without a stream is asked once more, this much later.
  static const retryWhenOff = Duration(minutes: 10);

  /// A full server's `Retry-After` when it sends none.
  static const defaultRetryAfter = Duration(seconds: 60);

  /// How long the app may be in the background before the stream closes.
  static const hiddenGrace = Duration(seconds: 30);

  /// How often to poll while the stream is unavailable for now (full, or
  /// failing), once this server has shown it has streams. Null: poll once
  /// on falling back, and not again until something else asks.
  ///
  /// A server that has never answered with a stream (today's, which answers
  /// 404) is never polled on a timer: the page does exactly what it did
  /// before streams.
  final Duration? pollEvery;

  final LiveStreamOpener _open;
  final LivePoller<T> _poll;
  final T? Function(Object? json) _parse;
  final void Function(T value) _onData;
  final Random _random;

  LiveMode _mode = LiveMode.idle;
  LiveMode _modeBeforePause = LiveMode.idle;
  bool _started = false;
  bool _closed = false;
  bool _visible = true;
  bool _paused = false;

  String? _lastId;
  Duration _retry = defaultRetry;
  int _failures = 0;

  /// This server has answered with a stream (or said it is full of them).
  bool _streamsSeen = false;
  bool _wasOff = false;
  bool _offRetried = false;

  /// The time to try the stream again came while the app was hidden.
  bool _retryDue = false;

  // The connection: [_attempt] numbers it, so anything arriving from one
  // already let go of is ignored.
  int _attempt = 0;
  Completer<void>? _abort;
  SseResponse? _response;
  StreamSubscription<SseFrame>? _frames;

  Timer? _openTimer;
  Timer? _silenceTimer;
  Timer? _reconnectTimer;
  Timer? _streamRetryTimer;
  Timer? _pollTimer;
  Timer? _graceTimer;
  bool _pollInFlight = false;

  LiveMode get mode => _mode;

  /// The `id` of the last snapshot, sent as `Last-Event-ID` on reconnect.
  String? get lastEventId => _lastId;

  /// Opens the stream. Calling it again does nothing.
  void start() {
    if (_started || _closed) return;
    _started = true;
    if (_paused) return; // opened when the app comes back
    _connect();
  }

  /// The page loaded itself again (after a payment, a retry), which used to
  /// mean polling the room again: a poll now, unless the stream is the
  /// source. Starts the client the first time.
  void refresh() {
    if (_closed) return;
    if (!_started) {
      start();
      return;
    }
    if (_mode == LiveMode.streaming || _mode == LiveMode.connecting) return;
    _pollOnce();
  }

  /// The app went to the background: the stream closes if it stays there
  /// for [hiddenGrace].
  void hidden() {
    if (_closed || !_visible) return;
    _visible = false;
    _graceTimer?.cancel();
    _graceTimer = Timer(hiddenGrace, _pause);
  }

  /// The app is back: the stream reopens, with the last id, if it closed.
  void shown() {
    if (_closed || _visible) return;
    _visible = true;
    _graceTimer?.cancel();
    _graceTimer = null;
    if (_paused) _resume();
  }

  /// Closes the stream and stops every timer, for good.
  void close() {
    if (_closed) return;
    _closed = true;
    _teardown();
    _cancel(_reconnectTimer);
    _cancel(_streamRetryTimer);
    _cancel(_pollTimer);
    _cancel(_graceTimer);
    _reconnectTimer = _streamRetryTimer = _pollTimer = _graceTimer = null;
    _mode = LiveMode.closed;
  }

  // ─── The stream ──────────────────────────────────────────────────────

  void _connect() {
    if (_closed || _paused) return;
    _teardown();
    _cancel(_reconnectTimer);
    _cancel(_streamRetryTimer);
    _reconnectTimer = _streamRetryTimer = null;
    _retryDue = false;

    final attempt = _attempt;
    final abort = Completer<void>();
    _abort = abort;
    _mode = LiveMode.connecting;
    _openTimer = Timer(openDeadline, () => _failed(attempt));
    Future<SseResponse>.sync(
      () => _open(lastEventId: _lastId, abort: abort.future),
    ).then(
      (response) => _opened(attempt, response),
      onError: (Object _) => _failed(attempt),
    );
  }

  void _opened(int attempt, SseResponse response) {
    if (attempt != _attempt) {
      response.close();
      return;
    }
    if (response.isEventStream) {
      _streamsSeen = true;
      _response = response;
      _frames = const SseDecoder().bind(response.body).listen(
            (frame) => _frame(attempt, frame),
            onError: (Object _) => _ended(attempt),
            onDone: () => _ended(attempt),
            cancelOnError: true,
          );
      return;
    }

    final status = response.statusCode;
    if (status == 503) {
      // Full, or a gateway between deploys: only the body tells which.
      final retryAfter = response.retryAfter;
      response.readErrorCode().then((code) {
        if (attempt != _attempt) return;
        if (code == 'LIVE_STREAM_FULL') {
          _teardown();
          _streamsSeen = true;
          _fallBack(retryAfter ?? defaultRetryAfter);
        } else {
          _failed(attempt);
        }
      });
      return;
    }

    response.close();
    _teardown();
    if (status == 404 ||
        status == 405 ||
        status == 501 ||
        status == 422 ||
        response.isSuccess) {
      _off();
    } else if (status == 429) {
      _fallBack(response.retryAfter ?? defaultRetryAfter);
    } else if (status == 401 || status == 403) {
      // As the poll handles it -- the poll refreshes the session on a 401 --
      // then the stream again; counted, so it cannot go round for ever.
      _pollOnce();
      _afterFailure(polled: true);
    } else {
      _afterFailure();
    }
  }

  void _frame(int attempt, SseFrame frame) {
    if (attempt != _attempt) return;
    final retry = frame.retry;
    if (retry != null) {
      _retry =
          Duration(milliseconds: retry.clamp(1000, maxBackoff.inMilliseconds));
    }
    final id = frame.id;
    if (id != null) _lastId = id.isEmpty ? null : id;

    switch (frame.event) {
      case 'snapshot':
        _established();
        final value = _decode(frame.data);
        if (value != null) _deliver(value, fromPoll: false);
      case 'ping':
        _established();
      case 'gone':
        _gone();
        return;
      default:
        // `retry:` alone, or an event this client does not know.
        break;
    }
    if (attempt == _attempt && _mode == LiveMode.streaming) {
      _cancel(_silenceTimer);
      _silenceTimer = Timer(silenceLimit, () => _ended(attempt));
    }
  }

  void _established() {
    if (_mode == LiveMode.streaming) return;
    _mode = LiveMode.streaming;
    _failures = 0;
    _cancel(_openTimer);
    _cancel(_pollTimer);
    _openTimer = _pollTimer = null;
  }

  /// The stream ended: by the server (its lifetime, a deploy), the network,
  /// or [silenceLimit] without a frame.
  void _ended(int attempt) {
    if (attempt != _attempt || _closed) return;
    final wasStreaming = _mode == LiveMode.streaming;
    _teardown();
    if (wasStreaming) {
      _scheduleReconnect();
    } else {
      // Over before a snapshot or a ping: the open failed.
      _afterFailure();
    }
  }

  void _failed(int attempt) {
    if (attempt != _attempt || _closed) return;
    _teardown();
    _afterFailure();
  }

  void _afterFailure({bool polled = false}) {
    _failures++;
    if (_failures >= failuresBeforePolling) {
      _failures = 0;
      _fallBack(retryAfterFailures);
      return;
    }
    // The first failure in a row: the poll keeps the page current while the
    // stream is tried again -- and gives a page that has just opened what
    // it always had.
    if (_failures == 1 && !polled && !(_pollTimer?.isActive ?? false)) {
      _pollOnce();
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _mode = LiveMode.reconnecting;
    _cancel(_reconnectTimer);
    _reconnectTimer = Timer(_backoff(), () {
      _reconnectTimer = null;
      _connect();
    });
  }

  /// `retry` for the first reconnect, doubled for each further failure in a
  /// row up to [maxBackoff], plus 0-100 % jitter: a hall reconnecting after
  /// a deploy does not come back all at once.
  Duration _backoff() {
    var base = _retry;
    for (var i = 1; i < _failures && base < maxBackoff; i++) {
      base *= 2;
    }
    if (base > maxBackoff) base = maxBackoff;
    return base + base * _random.nextDouble();
  }

  void _gone() {
    _teardown();
    _cancel(_reconnectTimer);
    _cancel(_streamRetryTimer);
    _cancel(_pollTimer);
    _reconnectTimer = _streamRetryTimer = _pollTimer = null;
    _mode = LiveMode.gone;
    // What the poll says now is what the page shows.
    _pollOnce();
  }

  /// Lets go of the connection, whatever state it is in.
  void _teardown() {
    _attempt++;
    _cancel(_openTimer);
    _cancel(_silenceTimer);
    _openTimer = _silenceTimer = null;
    final frames = _frames;
    _frames = null;
    frames?.cancel();
    final response = _response;
    _response = null;
    response?.close();
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  // ─── The poll ────────────────────────────────────────────────────────

  void _off() {
    _mode = LiveMode.off;
    _cancel(_pollTimer);
    _pollTimer = null;
    // Once: the poll the page has always made. The ten-minute retry finding
    // the stream still off changes nothing, so it polls nothing.
    if (!_wasOff) _pollOnce();
    _wasOff = true;
    if (!_offRetried) {
      _offRetried = true;
      _scheduleStreamRetry(retryWhenOff);
    }
  }

  void _fallBack(Duration retryIn) {
    _mode = LiveMode.polling;
    _startPolling();
    _scheduleStreamRetry(retryIn);
  }

  void _startPolling() {
    if (_pollTimer?.isActive ?? false) return;
    _pollOnce();
    final every = pollEvery;
    if (every != null && _streamsSeen) {
      _pollTimer = Timer.periodic(every, (_) => _pollOnce());
    }
  }

  void _scheduleStreamRetry(Duration after) {
    _cancel(_streamRetryTimer);
    _streamRetryTimer = Timer(after, () {
      _streamRetryTimer = null;
      if (_closed) return;
      if (_paused) {
        _retryDue = true;
        return;
      }
      _connect();
    });
  }

  void _pollOnce() {
    if (_closed || _pollInFlight) return;
    _pollInFlight = true;
    Future<T?>.sync(_poll).then(
      (value) {
        if (value != null) _deliver(value, fromPoll: true);
      },
      onError: (Object _) {
        // As the page's poll always has: a failed poll leaves what is shown.
      },
    ).whenComplete(() => _pollInFlight = false);
  }

  void _deliver(T value, {required bool fromPoll}) {
    if (_closed) return;
    // A poll answered after the stream took over is older than the stream.
    if (fromPoll && _mode == LiveMode.streaming) return;
    _onData(value);
  }

  T? _decode(String data) {
    try {
      return _parse(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  // ─── The app in the background ───────────────────────────────────────

  void _pause() {
    _graceTimer = null;
    if (_closed || _visible || _paused) return;
    _paused = true;
    _modeBeforePause = _mode;
    _teardown();
    _cancel(_reconnectTimer);
    _cancel(_pollTimer);
    _reconnectTimer = _pollTimer = null;
    if (_started) _mode = LiveMode.paused;
  }

  void _resume() {
    _paused = false;
    switch (_modeBeforePause) {
      case LiveMode.idle:
        if (_started) {
          _connect();
        } else {
          _mode = LiveMode.idle;
        }
      case LiveMode.gone:
      case LiveMode.closed:
        _mode = _modeBeforePause;
      case LiveMode.off:
        _mode = LiveMode.off;
        if (_retryDue) _connect();
      case LiveMode.polling:
        _mode = LiveMode.polling;
        if (pollEvery != null && _streamsSeen) _startPolling();
        if (_retryDue) _connect();
      case LiveMode.connecting:
      case LiveMode.streaming:
      case LiveMode.reconnecting:
      case LiveMode.paused:
        _failures = 0;
        _connect();
    }
  }

  static void _cancel(Timer? timer) => timer?.cancel();
}
