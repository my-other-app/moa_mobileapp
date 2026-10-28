import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/events/data/registration_requests_api.dart';
import 'package:finnet/features/events/domain/registration_request.dart';

/// The signed-in person's registrations under review (`GET
/// /registration-requests/mine`), for My events' "Under review" and the
/// event page's button.
@immutable
class MyRegistrationRequests {
  /// Every request the server listed, open ones first.
  final List<RegistrationRequest> items;

  /// Read at least once: from the phone's copy, or the server.
  final bool loaded;

  /// False once the server said it has no such route (404, an older
  /// server): nothing of it is shown.
  final bool supported;

  const MyRegistrationRequests({
    this.items = const [],
    this.loaded = false,
    this.supported = true,
  });

  /// Waiting for the club, or confirmed and waiting for the payment.
  List<RegistrationRequest> get open => supported
      ? [
          for (final r in items)
            if (r.isOpen) r
        ]
      : const [];

  /// The open request for the event [eventId], if there is one.
  RegistrationRequest? openFor(int? eventId) {
    if (eventId == null || eventId <= 0) return null;
    for (final request in open) {
      if (request.event?.id == eventId) return request;
    }
    return null;
  }
}

final myRegistrationRequestsProvider = StateNotifierProvider<
    MyRegistrationRequestsNotifier, MyRegistrationRequests>((ref) {
  return MyRegistrationRequestsNotifier(
      ref.watch(registrationRequestsApiProvider));
});

class MyRegistrationRequestsNotifier
    extends StateNotifier<MyRegistrationRequests> {
  MyRegistrationRequestsNotifier(this._api, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const MyRegistrationRequests());

  final RegistrationRequestsApi _api;
  final DateTime Function() _now;

  Future<void>? _refreshing;
  DateTime? _lastFresh;

  /// The phone's copy at once (the first time), then the server's. One
  /// read at a time: callers share the one under way. A failure keeps what
  /// is shown; a 404 hides the section.
  Future<void> refresh() => _refreshing ??= _read().whenComplete(() {
        _refreshing = null;
      });

  /// [refresh], unless the server answered within [age].
  Future<void> refreshIfOlderThan(Duration age) {
    final last = _lastFresh;
    if (last != null && _now().difference(last) < age) {
      return _refreshing ?? Future.value();
    }
    return refresh();
  }

  Future<void> _read() async {
    if (!state.loaded) {
      final saved = await _api.savedMine();
      if (saved != null && mounted && !state.loaded) {
        state = MyRegistrationRequests(items: saved, loaded: true);
      }
    }
    try {
      final fresh = await _api.mine();
      if (!mounted) return;
      _lastFresh = _now();
      state = fresh == null
          ? const MyRegistrationRequests(loaded: true, supported: false)
          : MyRegistrationRequests(items: fresh, loaded: true);
    } catch (e) {
      debugPrint('Registration requests: $e');
      if (mounted && !state.loaded) {
        state = MyRegistrationRequests(
            items: state.items, loaded: true, supported: state.supported);
      }
    }
  }

  /// What this phone just learned about one request (sent, read on its
  /// screen, withdrawn): put in the list at once, before the next read.
  /// Nothing before the list was read, or once the server said it has none.
  void remember(RegistrationRequest request) {
    if (!state.loaded || !state.supported) return;
    bool same(RegistrationRequest r) =>
        (request.id.isNotEmpty && r.id == request.id) ||
        (request.token != null && r.token == request.token);
    final index = state.items.indexWhere(same);
    final items = [...state.items];
    if (index < 0) {
      items.insert(0, request);
    } else {
      items[index] = items[index].mergedWith(request);
    }
    state = MyRegistrationRequests(items: items, loaded: true);
  }
}
