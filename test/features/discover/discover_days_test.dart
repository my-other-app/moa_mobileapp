import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/discover_days.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('days in India', () {
    test('today is India\'s, whatever the phone\'s zone', () {
      // 20:00 UTC is already the next day in India (01:30).
      expect(istDay(DateTime.utc(2026, 10, 19, 20)), '2026-10-20');
      expect(istDay(DateTime.utc(2026, 10, 19, 18, 29)), '2026-10-19');
    });

    test('real days and months only', () {
      expect(isDay('2026-02-28'), isTrue);
      expect(isDay('2026-02-30'), isFalse);
      expect(isDay('2026-2-3'), isFalse);
      expect(isMonth('2026-12'), isTrue);
      expect(isMonth('2026-13'), isFalse);
    });

    test('month arithmetic crosses years', () {
      expect(addMonths('2026-12', 1), '2027-01');
      expect(addMonths('2026-01', -1), '2025-12');
      expect(lastOfMonth('2028-02'), '2028-02-29');
      expect(lastOfMonth('2026-02'), '2026-02-28');
    });

    test('labels', () {
      expect(monthLabel('2026-10'), 'October 2026');
      expect(dayShort('2026-10-17'), 'Sat 17 Oct');
      expect(rangeLabel('2026-10-17', '2026-10-20', today: '2026-10-01'),
          '17–20 Oct');
      expect(rangeLabel('2026-10-30', '2026-11-02', today: '2026-10-01'),
          '30 Oct – 2 Nov');
      expect(rangeLabel('2027-01-05', '2027-01-05', today: '2026-10-01'),
          '5 Jan 2027');
    });
  });

  group('the calendar grouping', () {
    test('weeks start on Monday, with blanks around the month', () {
      // 1 October 2026 is a Thursday.
      final weeks = monthWeeks('2026-10');
      expect(weeks.first, [null, null, null, '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04']);
      expect(weeks.last.first, '2026-10-26');
      expect(weeks.last, ['2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30', '2026-10-31', null]);
      expect(weeks.every((w) => w.length == 7), isTrue);
      expect(weeks.expand((w) => w).whereType<String>(), hasLength(31));
    });

    test('a month that starts on Monday has no leading blank', () {
      // 1 June 2026 is a Monday.
      expect(monthWeeks('2026-06').first.first, '2026-06-01');
    });

    test('counts by day, only days with something on', () {
      final month = parseCalendar({
        'month': '2026-10',
        'days': {
          '2026-10-03': 2,
          '2026-10-17': '4',
          '2026-10-18': 0,
          '2026-10-32': 5,
          'soon': 1,
        },
      }, month: '2026-10');
      expect(month.days, {'2026-10-03': 2, '2026-10-17': 4});
      expect(month.countOn('2026-10-17'), 4);
      expect(month.countOn('2026-10-18'), 0);
      expect(month.busyDays, ['2026-10-03', '2026-10-17']);
      expect(month.total, 6);
    });

    test('an answer that is not one is an empty month', () {
      final month = parseCalendar('nope', month: '2026-10');
      expect(month, const CalendarMonth(month: '2026-10'));
    });
  });
}
