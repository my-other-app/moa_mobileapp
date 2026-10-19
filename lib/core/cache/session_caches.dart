import 'package:flutter/foundation.dart';

/// Everything the app keeps on the phone about the person signed in --
/// saved API answers, saved tickets, kept PDFs, private pictures -- cleared
/// together when a session ends or another begins.
///
/// Each part is cleared on its own: one that fails (a platform error, a
/// file in use) is logged and does not stop the rest. The whole is capped
/// at [timeout], so a sign-out never hangs on the disk.
class SessionCaches {
  SessionCaches(this._parts, {this.timeout = const Duration(seconds: 5)});

  /// What to clear, by name (for the log).
  final Map<String, Future<void> Function()> _parts;
  final Duration timeout;

  Future<void> clearAll() async {
    try {
      await Future.wait([
        for (final part in _parts.entries) _clear(part.key, part.value),
      ]).timeout(timeout);
    } catch (e) {
      debugPrint('SessionCaches: clearing cut short: $e');
    }
  }

  static Future<void> _clear(String name, Future<void> Function() clear) async {
    try {
      await clear();
    } catch (e) {
      debugPrint('SessionCaches: could not clear $name: $e');
    }
  }
}
