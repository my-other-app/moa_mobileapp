import 'package:finnet/core/utils/time_ago.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from the notes tests when Notes gave way to Threads: the wording
/// was right there, and posts and comments now share it.
void main() {
  final now = DateTime(2026, 10, 16, 12);
  String ago(Duration d) => timeAgo(now.subtract(d), now: now);

  test('reads coarsely, which is all a post needs', () {
    expect(ago(const Duration(seconds: 5)), 'just now');
    expect(ago(const Duration(minutes: 1)), '1 minute ago');
    expect(ago(const Duration(minutes: 40)), '40 minutes ago');
    expect(ago(const Duration(hours: 1)), '1 hour ago');
    expect(ago(const Duration(hours: 5)), '5 hours ago');
    expect(ago(const Duration(days: 1)), '1 day ago');
    expect(ago(const Duration(days: 3)), '3 days ago');
    expect(ago(const Duration(days: 14)), '2 weeks ago');
    expect(ago(const Duration(days: 400)), '1 year ago');
  });

  test('singular and plural are not mixed up', () {
    // "1 days ago" is the kind of thing that survives to production.
    expect(ago(const Duration(days: 1)), isNot(contains('days')));
    expect(ago(const Duration(hours: 1)), isNot(contains('hours')));
  });

  test('a time in the future reads as just now, not a negative age', () {
    // A phone whose clock runs a few minutes slow sees fresh posts as being
    // from the future.
    expect(timeAgo(now.add(const Duration(minutes: 3)), now: now), 'just now');
  });
}
