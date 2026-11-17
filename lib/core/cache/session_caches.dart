import 'package:flutter/foundation.dart';

/// Everything the app keeps on the phone about the person signed in --
/// saved API answers, saved tickets, kept PDFs, private pictures -- cleared
/// together when a session ends or another begins.
///
/// Each part is cleared on its own: one that fails (a platform error, a
/// file in use) is logged and does not stop the rest. The whole is capped
/// at [timeout], so a sign-out never hangs on the disk.
class SessionCaches {
  SessionCaches(
    this._parts, {
    Map<String, Future<void> Function()> atSessionEnd = const {},
    this.timeout = const Duration(seconds: 5),
  }) : _atSessionEnd = atSessionEnd;

  /// What to clear, by name (for the log).
  final Map<String, Future<void> Function()> _parts;

  /// What to clear only when a session ends -- a sign-out, or the server
  /// ending it -- and not when one begins: what the person may have made
  /// on the phone before signing in (a quiz they joined) is theirs.
  final Map<String, Future<void> Function()> _atSessionEnd;
  final Duration timeout;

  /// [signingIn]: a session is beginning, so [_atSessionEnd]'s parts stay.
  Future<void> clearAll({bool signingIn = false}) async {
    try {
      await Future.wait([
        for (final part in _parts.entries) _clear(part.key, part.value),
        if (!signingIn)
          for (final part in _atSessionEnd.entries)
            _clear(part.key, part.value),
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
