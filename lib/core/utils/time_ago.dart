/// "2 hours ago", for a post or a comment.
///
/// Deliberately coarse: nothing a club posts is time-critical, and "3 days
/// ago" reads better than a timestamp nobody needs to the minute. Lived on
/// the old ClubNote entity as `relativeTime`; it moved here when Threads
/// replaced Notes, because posts and comments both need it.
///
/// A time in the future -- a phone whose clock runs slow -- reads as "just
/// now" rather than as a negative number of minutes.
String timeAgo(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);

  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  if (difference.inDays < 365) {
    final weeks = difference.inDays ~/ 7;
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  }
  final years = difference.inDays ~/ 365;
  return '$years ${years == 1 ? 'year' : 'years'} ago';
}
