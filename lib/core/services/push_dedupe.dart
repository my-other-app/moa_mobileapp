/// Shows and opens each push once.
///
/// The server may send one broadcast more than once: a job that ran again,
/// or -- while it moves broadcasts from one send per device to FCM topics --
/// a topic send and a device send that both reach a device. Every copy
/// carries the same `push_id` in its data, which is also the notification's
/// Android tag and APNs collapse id, so the system tray replaces rather than
/// stacks the copies it shows itself. In the foreground the app shows them,
/// and here a second copy is dropped; a tap on a second copy of something
/// already opened does nothing.
///
/// A push without a `push_id` (anything personal: a ticket, a payment, a
/// reminder) is always shown and opened. The ids are kept for the life of the
/// process, the most recent [capacity] of them (a set literal keeps its
/// order of insertion, so the first is the oldest).
class PushDedupe {
  PushDedupe({this.capacity = 256});

  final int capacity;
  final _shown = <String>{};
  final _opened = <String>{};

  /// The push's id, or null when it has none.
  static String? idOf(Map<String, dynamic>? data) {
    final id = data?['push_id']?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  /// True the first time a push is to be shown; false for a copy.
  bool firstShow(Map<String, dynamic>? data) => _first(_shown, idOf(data));

  /// True the first time a push is opened; false for a copy.
  bool firstOpen(Map<String, dynamic>? data) => _first(_opened, idOf(data));

  bool _first(Set<String> seen, String? id) {
    if (id == null) return true;
    if (!seen.add(id)) return false;
    while (seen.length > capacity) {
      seen.remove(seen.first);
    }
    return true;
  }
}
