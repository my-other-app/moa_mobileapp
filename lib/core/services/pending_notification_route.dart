import 'dart:convert';

/// Where a notification that *launched* the app points, held until the app
/// can open it.
///
/// A tap on a push while the app is closed is reported during start-up --
/// `NotificationService.initialize()` runs before `runApp`, so there is no
/// navigator yet and pushing the route there did nothing. The route is held
/// here instead, and the splash screen takes it once it has sent the person
/// home.
///
/// Pure Dart, with the route lookup handed in, so it can be tested without
/// Firebase.
class PendingNotificationRoute {
  PendingNotificationRoute(this._routeFor);

  final String? Function(Map<String, dynamic> data) _routeFor;
  String? _route;

  /// Hold where a launch notification's [data] points.
  ///
  /// Data that routes nowhere is ignored. The first route held wins: one
  /// launch comes from one tap, and a second report of it must not replace
  /// the first.
  void hold(Map<String, dynamic>? data) {
    if (_route != null || data == null) return;
    _route = _routeFor(data);
  }

  /// [hold], for a local notification's payload -- the push's data as JSON,
  /// which is how foreground pushes are re-shown. A payload that is not ours
  /// is ignored.
  void holdPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) hold(Map<String, dynamic>.from(data));
    } catch (_) {
      // Not JSON: nothing to open.
    }
  }

  /// The held route, handed over exactly once: it is cleared as it is taken.
  String? take() {
    final route = _route;
    _route = null;
    return route;
  }

  /// Drop the held route without opening it.
  void clear() => _route = null;
}
