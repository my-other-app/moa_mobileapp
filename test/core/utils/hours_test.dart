import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/utils/hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a decimal hour count becomes an exact length', () {
    expect(hoursToDuration(2.5), const Duration(hours: 2, minutes: 30));
    expect(hoursToDuration(3), const Duration(hours: 3));
    expect(hoursToDuration(0.75), const Duration(minutes: 45));
  });

  test('hours read the way people say them', () {
    expect(formatHours(2), '2');
    expect(formatHours(2.0), '2');
    expect(formatHours(2.5), '2.5');
    expect(formatHours(1.75), '1.75');
    expect(hoursLabel(1), '1 Hour');
    expect(hoursLabel(2.5), '2.5 Hours');
  });

  test('an event keeps its half hour', () {
    final started = DateTime.now().subtract(const Duration(hours: 2, minutes: 15));
    final info = EventInfo.fromJson({
      'id': 1,
      'event_datetime': started.toUtc().toIso8601String(),
      'duration': 2.5,
    });
    expect(info.duration, 2.5);
    // 2h15m into a 2.5-hour event: not over yet. Rounded to 2 hours it was.
    expect(info.isEventEnded, isFalse);
  });
}
