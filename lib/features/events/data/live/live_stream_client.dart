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

  /// The event is not live (as far as the last poll or snapshot says): the
  /// poll as before streams, and no stream.
  notLive,

  /// Opening the stream; nothing has come down it yet.
  connecting,

  /// A snapshot or a ping has come down the stream: it is the source.
  streaming,

  /// Waiting to open the stream again.
  reconnecting,

  /// The stream is unavailable for now (full, or failing): what was fetched
  /// stands, and the stream is tried again later. Nothing on a timer.
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
/// (`GET /events/{id}/live/stream?view=...`) while the event is live and the
/// server has one, from the view's poll otherwise, as the live room's stream
/// contract (LIVE_SSE) asks of every client:
///
/// - The poll comes first -- the one fetch the page has always made, on
///   [start] and on every [refresh] -- and the stream opens only while
///   [shouldStream] says so of what the poll (or a snapshot) gave: the event
///   is live. A snapshot saying it no longer is closes the stream.
/// - Every `snapshot` is the poll's own body, parsed with the poll's parser
///   and handed to [onData]; its `id` is sent back as `Last-Event-ID` on every
///   reconnect, so a stream that missed nothing sends no snapshot again.
/// - `retry:` sets the reconnect delay: that, then doubled for each failure
///   in a row up to 30 s, each with 0-100 % jitter added.
/// - An open that gets no snapshot or ping within 20 s has failed; a stream
///   silent for 45 s (three missed pings) is dropped and reopened.
/// - Falls back to the poll -- one fetch, never one on a timer, and none when
///   the poll is what the page is showing already -- when the server has no
///   stream (404/405/501/422, or a 2xx that is not one: tried once more after
///   10 minutes), when it is full (503 `LIVE_STREAM_FULL`, or 429: tried
///   again after `Retry-After`, 60 s without one), or after three failed
///   attempts in a row (tried again after 5 minutes). A full server is
///   shedding load: a hall of pages polling it would make that worse.
/// - `gone`: closed and not reopened; one poll says what the page shows now.
/// - In the background: closed after [hiddenGrace], reopened (with the last
///   id) when the app is back.
///
/// With [pollEvery], the view is also polled at that interval while the app
/// is in front and the stream is not the source -- the live room's screens,
/// whose server has streams switched off, and the event page's strip. The
/// poll stops at once when the app goes to the background (the stream keeps
/// its grace), and comes back with a poll when it returns. [shouldPoll]
/// says, of the last value (null before one came), whether polling is
/// still worth it (a room that has closed); [onPollError] hears every
/// failed poll.
///
/// There is never more than one stream open or one poll in flight, and
/// [close] leaves no timer running.
class LiveStreamClient<T> {
  LiveStreamClient({
    required LiveStreamOpener open,
    required LivePoller<T> poll,
    required T? Function(Object? json) parse,
    required void Function(T value) onData,
    required bool Function(T value) shouldStream,
    Duration? pollEvery,
    bool Function(T? value)? shouldPoll,
    void Function(Object error)? onPollError,
    Random? random,
  })  : _open = open,
        _poll = poll,
        _parse = parse,
        _onData = onData,
        _shouldStream = shouldStream,
        _pollEvery = pollEvery,
        _shouldPoll = shouldPoll,
        _onPollError = onPollError,
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

  final LiveStreamOpener _open;
  final LivePoller<T> _poll;
  final T? Function(Object? json) _parse;
  final void Function(T value) _onData;
  final bool Function(T value) _shouldStream;
  final Duration? _pollEvery;
  final bool Function(T? value)? _shouldPoll;
  final void Function(Object error)? _onPollError;
  final Random _random;

  /// The last value delivered, from the poll or the stream.
  T? _last;

  /// The poll on [_pollEvery], while the app is in front.
  Timer? _pollTimer;

  LiveMode _mode = LiveMode.idle;
  LiveMode _modeBeforePause = LiveMode.idle;
  bool _started = false;
  bool _closed = false;
  bool _visible = true;
  bool _paused = false;

  /// What the last poll or snapshot said: the event is live.
  bool _wantStream = false;

  String? _lastId;
  Duration _retry = defaultRetry;
  int _failures = 0;
  bool _offRetried = false;

  /// A poll has been made since the stream last delivered: what the page
  /// shows is the poll's, so falling back needs no second fetch.
  bool _polledSinceStream = false;

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
  Timer? _graceTimer;
  bool _pollInFlight = false;

  LiveMode get mode => _mode;

  /// The `id` of the last snapshot, sent as `Last-Event-ID` on reconnect.
  String? get lastEventId => _lastId;

  /// The page's first fetch of the room; the stream follows if it says the
  /// event is live. Calling it again does nothing.
  void start() {
    if (_started || _closed) return;
    _started = true;
    _mode = LiveMode.notLive;
    _pollOnce();
    _startPolling();
  }

  /// The page loaded itself again (after a payment, a retry), which has
  /// always meant fetching the room again: a fetch now -- which opens the
  /// stream if the event has gone live -- unless the stream is the source.
  /// Starts the client the first time.
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
    _stopPolling();
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
    if (_started && _pollEvery != null) {
      // What happened while away, now rather than at the next tick -- unless
      // the stream is reopening, which brings it (from the last id).
      final reopening =
          _mode == LiveMode.connecting || _mode == LiveMode.streaming;
      if (!reopening && _worthPolling) _pollOnce();
      _startPolling();
    }
  }

  /// Closes the stream and stops every timer, for good.
  void close() {
    if (_closed) return;
    _closed = true;
    _teardown();
    _stopPolling();
    _cancel(_reconnectTimer);
    _cancel(_streamRetryTimer);
    _cancel(_graceTimer);
    _reconnectTimer = _streamRetryTimer = _graceTimer = null;
    _mode = LiveMode.closed;
  }

  /// Opens or closes the stream for what the last poll or snapshot said.
  void _reconsider() {
    if (_closed || _paused || !_started) return;
    if (_wantStream) {
      if (_mode == LiveMode.notLive) _connect();
      return;
    }
    switch (_mode) {
      case LiveMode.connecting:
      case LiveMode.streaming:
      case LiveMode.reconnecting:
      case LiveMode.polling:
      case LiveMode.off:
        // Not live (any more): no stream, and no retry of one.
        _teardown();
        _cancel(_reconnectTimer);
        _cancel(_streamRetryTimer);
        _reconnectTimer = _streamRetryTimer = null;
        _retryDue = false;
        _failures = 0;
        _mode = LiveMode.notLive;
      default:
        break;
    }
  }

  // ─── The stream ──────────────────────────────────────────────────────

  void _connect() {
    if (_closed || _paused) return;
    _teardown();
    _cancel(_reconnectTimer);
    _cancel(_streamRetryTimer);
    _reconnectTimer = _streamRetryTimer = null;
    _retryDue = false;
    if (!_wantStream) {
      _mode = LiveMode.notLive;
      return;
    }

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
      _afterFailure();
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
    _polledSinceStream = false;
    _cancel(_openTimer);
    _openTimer = null;
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

  void _afterFailure() {
    _failures++;
    if (_failures >= failuresBeforePolling) {
      _failures = 0;
      _fallBack(retryAfterFailures);
      return;
    }
    // The first failure in a row after the stream had been the source: one
    // fetch, so what was missed while it broke is not missed for long.
    if (_failures == 1) _pollIfStale();
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
    _reconnectTimer = _streamRetryTimer = null;
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
    _pollIfStale();
    if (!_offRetried) {
      _offRetried = true;
      _scheduleStreamRetry(retryWhenOff);
    }
  }

  void _fallBack(Duration retryIn) {
    _mode = LiveMode.polling;
    _pollIfStale();
    _scheduleStreamRetry(retryIn);
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

  /// One fetch, unless the page is showing the poll's answer already.
  void _pollIfStale() {
    if (!_polledSinceStream) _pollOnce();
  }

  void _pollOnce() {
    if (_closed || _pollInFlight) return;
    _pollInFlight = true;
    _polledSinceStream = true;
    Future<T?>.sync(_poll).then(
      (value) {
        if (value != null) _deliver(value, fromPoll: true);
      },
      onError: (Object error) {
        // As the page's poll always has: a failed poll leaves what is shown.
        if (!_closed) _onPollError?.call(error);
      },
    ).whenComplete(() => _pollInFlight = false);
  }

  bool get _worthPolling {
    final shouldPoll = _shouldPoll;
    return shouldPoll == null || shouldPoll(_last);
  }

  void _startPolling() {
    final every = _pollEvery;
    if (every == null || _closed || !_visible) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(every, (_) {
      if (_closed || !_visible || _paused) return;
      // The stream is the source: nothing to ask.
      if (_mode == LiveMode.streaming) return;
      if (!_worthPolling) return;
      _pollOnce();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _deliver(T value, {required bool fromPoll}) {
    if (_closed) return;
    // A poll answered after the stream took over is older than the stream.
    if (fromPoll && _mode == LiveMode.streaming) return;
    _wantStream = _shouldStream(value);
    _last = value;
    _onData(value);
    _reconsider();
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
    _reconnectTimer = null;
    if (_started) _mode = LiveMode.paused;
  }

  void _resume() {
    _paused = false;
    final before = _modeBeforePause;
    switch (before) {
      case LiveMode.idle:
        // Hidden before it started: [start] has set the mode since, if it ran.
        break;
      case LiveMode.notLive:
      case LiveMode.gone:
      case LiveMode.closed:
        _mode = before;
      case LiveMode.off:
      case LiveMode.polling:
        _mode = before;
        if (_retryDue) _connect();
      case LiveMode.connecting:
      case LiveMode.streaming:
      case LiveMode.reconnecting:
      case LiveMode.paused:
        _failures = 0;
        _connect();
    }
    // A poll that came back while hidden may have said the event went live.
    _reconsider();
  }

  static void _cancel(Timer? timer) => timer?.cancel();
}
