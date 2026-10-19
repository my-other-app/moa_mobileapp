import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/network/interceptors/retry_interceptor.dart';

/// Whether the app can reach the server, as its own requests find out.
///
/// There is no connectivity plugin: a phone on Wi-Fi without internet says
/// it is connected, so the requests themselves are the better witness.
/// Every request that got no answer at all marks the app offline; every
/// answer, of any status, marks it online. While offline, a probe (a TCP
/// connect to the API's host, nothing sent) runs every [probeEvery] so the
/// banner goes away without the person having to do anything.
///
/// Coming back counts up [backOnline]. The screens on show watch it
/// ([backOnlineProvider], [RefreshWhenBackOnline]) and read themselves
/// again, so what was drawn from the saved copy is brought up to date
/// without a pull or a tap.
class NetworkStatus {
  NetworkStatus({
    Future<bool> Function()? probe,
    this.probeEvery = const Duration(seconds: 10),
  }) : _probe = probe;

  /// The app's one instance, fed by [NetworkStatusInterceptor].
  static final NetworkStatus instance = NetworkStatus();

  final Future<bool> Function()? _probe;
  final Duration probeEvery;

  final ValueNotifier<bool> _offline = ValueNotifier<bool>(false);
  final ValueNotifier<int> _backOnline = ValueNotifier<int>(0);

  /// True while the last request could not reach the server.
  ValueListenable<bool> get offline => _offline;

  bool get isOffline => _offline.value;

  /// How many times the app has come back online since it started: one
  /// more each time [offline] goes from true to false.
  ValueListenable<int> get backOnline => _backOnline;

  Timer? _probing;
  bool _probeRunning = false;

  /// Where the probe connects; set from the API's base URL.
  Uri? probeTarget;

  /// A request got an answer.
  void reportOnline() {
    _probing?.cancel();
    _probing = null;
    if (_offline.value) {
      _offline.value = false;
      _backOnline.value++;
    }
  }

  /// A request got no answer at all.
  void reportOffline() {
    if (!_offline.value) _offline.value = true;
    _probing ??= Timer.periodic(probeEvery, (_) => _runProbe());
  }

  /// Check now (the banner's "Try again"). Answers whether it is back.
  Future<bool> checkNow() async {
    await _runProbe();
    return !_offline.value;
  }

  Future<void> _runProbe() async {
    if (_probeRunning || !_offline.value) return;
    _probeRunning = true;
    try {
      final reachable = await (_probe ?? _connect)();
      if (reachable) reportOnline();
    } catch (_) {
      // Still offline.
    } finally {
      _probeRunning = false;
    }
  }

  Future<bool> _connect() async {
    final target = probeTarget;
    if (target == null || target.host.isEmpty) return false;
    final port = target.hasPort
        ? target.port
        : (target.scheme == 'http' ? 80 : 443);
    final socket = await Socket.connect(
      target.host,
      port,
      timeout: const Duration(seconds: 4),
    );
    socket.destroy();
    return true;
  }

  @visibleForTesting
  void dispose() {
    _probing?.cancel();
    _offline.dispose();
    _backOnline.dispose();
  }
}

/// The app's [NetworkStatus]; overridden in tests.
final networkStatusProvider =
    Provider<NetworkStatus>((ref) => NetworkStatus.instance);

/// [NetworkStatus.backOnline], for providers: one that watches it is read
/// again each time the app comes back online.
///
/// A provider of saved-then-fresh data watches it, so the copy drawn from
/// the phone while offline is replaced by the server's as soon as the
/// server can be reached. A notifier that holds more than it fetched (a
/// list paged further, likes) listens instead and refreshes itself, rather
/// than being rebuilt from nothing.
final backOnlineProvider = Provider<int>((ref) {
  final count = ref.watch(networkStatusProvider).backOnline;
  void changed() => ref.state = count.value;
  count.addListener(changed);
  ref.onDispose(() => count.removeListener(changed));
  return count.value;
});

/// For a screen that loads in its `State`: [onBackOnline] runs each time the
/// app comes back online while the screen is up.
///
/// [backOnlineStatus] is the [NetworkStatus] listened to; the app's own
/// unless a test gives another.
mixin RefreshWhenBackOnline<W extends StatefulWidget> on State<W> {
  ValueListenable<int>? _backOnline;

  NetworkStatus get backOnlineStatus => NetworkStatus.instance;

  /// Read the screen again: the network is back.
  void onBackOnline();

  void _onBackOnline() {
    if (mounted) onBackOnline();
  }

  @override
  void initState() {
    super.initState();
    _backOnline = backOnlineStatus.backOnline..addListener(_onBackOnline);
  }

  @override
  void dispose() {
    _backOnline?.removeListener(_onBackOnline);
    super.dispose();
  }
}

/// Feeds [NetworkStatus] from every request the app's Dio makes.
class NetworkStatusInterceptor extends Interceptor {
  NetworkStatusInterceptor([NetworkStatus? status])
      : _status = status ?? NetworkStatus.instance;

  final NetworkStatus _status;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _status.reportOnline();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      _status.reportOnline();
    } else if (RetryInterceptor.isConnectionFailure(err)) {
      _status.reportOffline();
    }
    handler.next(err);
  }
}
