import 'package:flutter/foundation.dart';

/// The inbox lines of the pushes the person tapped, waiting for the inbox
/// to mark them read.
///
/// A push that has an inbox line names it in its data as `notification_id`
/// (the server's app/core/notifications/fanout.py): the line's own id, or
/// the key of the send that wrote it, which the server turns into the
/// reader's own line. A tap -- on a push that launched the app, brought it
/// back, or was re-shown while it was open -- is noted here by the push
/// service, before anything else happens and without waiting on anything,
/// so opening the push's screen is never held up by it.
/// `PersonalDataSync` takes the lines once someone is signed in and the
/// inbox can mark them (NotificationsNotifier.markOpened), and the icon's
/// badge drops.
///
/// Kept apart from the push service, as `PushArrivals` is, so reading it
/// does not load Firebase.
class OpenedPushLines {
  OpenedPushLines._();

  /// The push data key that names the line.
  static const dataKey = 'notification_id';

  /// Bumped by each line noted.
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static final List<String> _waiting = [];

  /// The line a push's [data] names, or null for a push without one (an
  /// older server's, or one with no inbox line).
  static String? idIn(Map<String, dynamic> data) {
    final id = data[dataKey]?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  /// A push was tapped: note its line, if it names one, once.
  static void opened(Map<String, dynamic> data) {
    final id = idIn(data);
    if (id == null || _waiting.contains(id)) return;
    _waiting.add(id);
    count.value++;
  }

  /// The lines noted so far, handed over once.
  static List<String> take() {
    final out = List<String>.of(_waiting);
    _waiting.clear();
    return out;
  }

  /// Forget them: the session they were tapped in has ended.
  static void clear() => _waiting.clear();

  @visibleForTesting
  static List<String> get waiting => List.unmodifiable(_waiting);
}
