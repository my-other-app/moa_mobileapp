import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/shared/utils/external_links.dart';

/// Hands [entry] to the phone's calendar app; answers whether it opened.
typedef CalendarAdder = Future<bool> Function(CalendarEntry entry);

Future<bool> _addWithPlugin(CalendarEntry entry) {
  return cal.Add2Calendar.addEvent2Cal(cal.Event(
    title: entry.title,
    description: entry.description,
    location: entry.location,
    startDate: entry.start,
    endDate: entry.end,
    iosParams: const cal.IOSParams(reminder: Duration(hours: 1)),
    androidParams: const cal.AndroidParams(emailInvites: []),
  ));
}

/// The phone's calendar (add_2_calendar). A provider so tests need no
/// platform channel.
final calendarAdderProvider = Provider<CalendarAdder>((ref) => _addWithPlugin);

/// How adding to the calendar went.
enum CalendarOutcome {
  /// The phone's calendar opened with the event filled in.
  calendar,

  /// No calendar app took it, so Google Calendar's page opened instead.
  web,

  /// Neither could open.
  failed,
}

/// "Add to calendar": the phone's calendar app first; when there is none,
/// or it refuses (permission, a platform error), Google Calendar's own
/// "add event" page, as the website offers. Never throws.
Future<CalendarOutcome> addToCalendar(
  CalendarEntry entry, {
  required CalendarAdder add,
  required LinkLauncher open,
}) async {
  try {
    if (await add(entry)) return CalendarOutcome.calendar;
  } catch (e) {
    debugPrint('Add to calendar: the calendar app refused: $e');
  }
  try {
    if (await open(googleCalendarUri(entry))) return CalendarOutcome.web;
  } catch (e) {
    debugPrint('Add to calendar: Google Calendar did not open: $e');
  }
  return CalendarOutcome.failed;
}

/// [addToCalendar] with the app's calendar and link launcher.
Future<CalendarOutcome> addToCalendarWith(
        WidgetRef ref, CalendarEntry entry) =>
    addToCalendar(
      entry,
      add: ref.read(calendarAdderProvider),
      open: ref.read(linkLauncherProvider),
    );
