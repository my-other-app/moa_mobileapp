/// Calendar days as India sees them, the way `/discover/*` takes them.
///
/// A day is a plain `YYYY-MM-DD` string and a month `YYYY-MM`: the API takes
/// them that way, they sort as text, and they never shift with the phone's
/// own clock. The arithmetic runs on UTC midnights, so no daylight-saving
/// change can skip or repeat a day. (The website's `utils/days.js`.)
library;

final _day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _month = RegExp(r'^(\d{4})-(\d{2})$');

/// India is UTC+5:30 all year.
const istOffset = Duration(hours: 5, minutes: 30);

String _pad(int n) => n.toString().padLeft(2, '0');

DateTime _utc(String day) => DateTime.utc(
      int.parse(day.substring(0, 4)),
      int.parse(day.substring(5, 7)),
      int.parse(day.substring(8, 10)),
    );

String _fromUtc(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

/// A real calendar day ("2026-02-30" is not one).
bool isDay(Object? value) {
  if (value is! String) return false;
  final m = _day.firstMatch(value);
  if (m == null) return false;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final at = DateTime.utc(y, mo, d);
  return at.year == y && at.month == mo && at.day == d;
}

/// A real month, from 1970 on.
bool isMonth(Object? value) {
  if (value is! String) return false;
  final m = _month.firstMatch(value);
  if (m == null) return false;
  final mo = int.parse(m[2]!);
  return mo >= 1 && mo <= 12 && int.parse(m[1]!) >= 1970;
}

/// The day it is in India at [at] (now by default).
String istDay([DateTime? at]) =>
    _fromUtc((at ?? DateTime.now()).toUtc().add(istOffset));

String addDays(String day, int n) => _fromUtc(_utc(day).add(Duration(days: n)));

int daysBetween(String from, String to) =>
    _utc(to).difference(_utc(from)).inDays;

/// 0 for Monday ... 6 for Sunday: weeks here start on a Monday.
int weekdayIndex(String day) => _utc(day).weekday - 1;

String monthOf(String day) => day.substring(0, 7);

String addMonths(String month, int n) {
  final y = int.parse(month.substring(0, 4));
  final m = int.parse(month.substring(5, 7)) - 1 + n;
  final d = DateTime.utc(y, m + 1, 1);
  return '${d.year}-${_pad(d.month)}';
}

String firstOfMonth(String month) => '$month-01';

String lastOfMonth(String month) =>
    addDays(firstOfMonth(addMonths(month, 1)), -1);

/// The month as weeks of seven, Monday first; a cell outside the month is
/// null.
List<List<String?>> monthWeeks(String month) {
  final first = firstOfMonth(month);
  final count = int.parse(lastOfMonth(month).substring(8, 10));
  final cells = <String?>[
    for (var i = 0; i < weekdayIndex(first); i++) null,
    for (var i = 1; i <= count; i++) '$month-${_pad(i)}',
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [
    for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
  ];
}

/// A span of days: both ends real, in order, no more than a year apart --
/// what the API accepts (`to` at most 366 days after `from`). One end alone
/// is that single day. Null when there is nothing usable.
({String from, String to})? dayRange(Object? from, Object? to) {
  final a = isDay(from) ? from as String : null;
  final b = isDay(to) ? to as String : null;
  if (a == null && b == null) return null;
  var lo = a ?? b!;
  var hi = b ?? a!;
  if (lo.compareTo(hi) > 0) (lo, hi) = (hi, lo);
  if (daysBetween(lo, hi) > 365) return null;
  return (from: lo, to: hi);
}

/// The day as a [DateTime] at midnight UTC, for formatting its name.
DateTime dayAsDate(String day) => _utc(day);

/// A [DateTime] as a day string, by its own calendar fields.
String dayFromDate(DateTime date) =>
    '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "October 2026".
String monthLabel(String month) =>
    '${_monthNames[int.parse(month.substring(5, 7)) - 1]} '
    '${month.substring(0, 4)}';

/// "October".
String monthWord(String month) =>
    _monthNames[int.parse(month.substring(5, 7)) - 1];

/// "Sat 17 Oct".
String dayShort(String day) {
  final m = int.parse(day.substring(5, 7));
  return '${_weekdayShort[weekdayIndex(day)]} ${int.parse(day.substring(8, 10))} '
      '${_monthNames[m - 1].substring(0, 3)}';
}

/// "17 Oct", "17–20 Oct", "28 Oct – 2 Nov"; with years when not this one.
String rangeLabel(String from, String to, {String? today}) {
  if (!isDay(from)) return '';
  final end = isDay(to) && to.compareTo(from) > 0 ? to : from;
  final year = (today ?? istDay()).substring(0, 4);
  final withYear = from.substring(0, 4) != year || end.substring(0, 4) != year;
  String one(String d) {
    final m = _monthNames[int.parse(d.substring(5, 7)) - 1].substring(0, 3);
    final text = '${int.parse(d.substring(8, 10))} $m';
    return withYear ? '$text ${d.substring(0, 4)}' : text;
  }

  if (end == from) return one(from);
  if (monthOf(from) == monthOf(end)) {
    return '${int.parse(from.substring(8, 10))}–${one(end)}';
  }
  return '${one(from)} – ${one(end)}';
}
