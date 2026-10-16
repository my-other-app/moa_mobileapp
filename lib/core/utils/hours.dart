// An event's length arrives from the API in hours, as a decimal: 2.5 is two
// and a half hours. Rounding it to whole hours (as `toInt()` did) ended a
// 2.5-hour event half an hour early everywhere the app does time maths.

/// The exact length, to the minute.
Duration hoursToDuration(num hours) => Duration(minutes: (hours * 60).round());

/// "2", "2.5", "1.75" — never "2.0".
String formatHours(num hours) {
  if (hours == hours.roundToDouble()) return hours.toInt().toString();
  return hours
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "1 Hour", "2.5 Hours".
String hoursLabel(num hours) =>
    '${formatHours(hours)} ${hours == 1 ? 'Hour' : 'Hours'}';
