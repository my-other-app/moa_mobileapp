import 'package:intl/intl.dart';

/// How an organiser's question is answered on the registration form.
enum QuestionControl {
  /// A text box (text, textarea, email, url, tel, number, and anything this
  /// build doesn't know -- an invisible required field can't be filled in).
  text,

  /// A date picker.
  date,

  /// A time picker.
  time,

  /// A date picker, then a time picker.
  dateTime,

  /// A dropdown.
  select,

  /// Radio buttons: pick one.
  radio,

  /// Tick boxes, one ticked at a time: a single "I agree" box, or a pick-one
  /// list, sent as one string that must be one of the options. The server
  /// now also takes a list of options for a checkbox question, but one
  /// deployed before that takes only a string, so a string is what is sent.
  checkbox,
}

/// The control for a question of `field_type` [fieldType]
/// (`app/api/events/schemas.py` FieldTypes).
QuestionControl questionControlOf(String fieldType) {
  switch (fieldType.trim().toLowerCase()) {
    case 'date':
      return QuestionControl.date;
    case 'time':
      return QuestionControl.time;
    case 'datetime':
    case 'datetime-local':
      return QuestionControl.dateTime;
    case 'select':
      return QuestionControl.select;
    case 'radio':
      return QuestionControl.radio;
    case 'checkbox':
      return QuestionControl.checkbox;
    default:
      return QuestionControl.text;
  }
}

/// Whether [control] is answered with a picker rather than typed.
bool isPickerControl(QuestionControl control) =>
    control == QuestionControl.date ||
    control == QuestionControl.time ||
    control == QuestionControl.dateTime;

/// What a ticked box sends when a checkbox question has no options of its
/// own -- the website's choice too.
const checkboxDefaultValue = 'Yes';

/// The values a checkbox question can be ticked with: its options, or a
/// single "Yes" when it has none.
List<String> checkboxValues(List<String> options) {
  final real = options.where((o) => o.trim().isNotEmpty).toList();
  return real.isEmpty ? const [checkboxDefaultValue] : real;
}

// The answers go to the server in the formats the website's date, time and
// datetime-local inputs send, so the organiser's export reads the same
// whichever way someone registered.

/// "2026-10-18".
String dateAnswer(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

/// "09:05" -- 24-hour.
String timeAnswer(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// "2026-10-18T09:05".
String dateTimeAnswer(DateTime moment) =>
    "${dateAnswer(moment)}T${timeAnswer(moment.hour, moment.minute)}";

/// What the field shows once picked: "18 Oct 2026".
String dateLabel(DateTime day) => DateFormat('d MMM yyyy').format(day);

/// "9:05 AM".
String timeLabel(int hour, int minute) =>
    DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));

/// "18 Oct 2026, 9:05 AM".
String dateTimeLabel(DateTime moment) =>
    '${dateLabel(moment)}, ${timeLabel(moment.hour, moment.minute)}';
