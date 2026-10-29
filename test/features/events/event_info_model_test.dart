import 'package:finnet/common/models/events/event_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The machine running the tests keeps India time (`TZ=Asia/Kolkata`).
final _inIndia = DateTime(2026, 11, 28).timeZoneOffset ==
    const Duration(hours: 5, minutes: 30);
const _india = 'reads the clock of a phone in India (TZ=Asia/Kolkata)';

void main() {
  test('no reg_enddate is no deadline, not "now"', () {
    expect(EventInfo.fromJson({'reg_enddate': null}).regEndDate, isNull);
    expect(EventInfo.fromJson({}).regEndDate, isNull);
    expect(
      EventInfo.fromJson({'reg_enddate': '2030-01-01T00:00:00Z'})
          .regEndDate!
          .toUtc(),
      DateTime.utc(2030),
    );
  });

  // Dart reads a time with an offset as a UTC time; the page showed its
  // hour, and DevFest (9 AM IST) read 3:30 AM.
  test('the dates are in the phone\'s time, with or without "Z"', () {
    final devFest = EventInfo.fromJson({
      'event_datetime': '2026-11-28T09:00:00+05:30',
      'reg_startdate': '2026-10-01T00:00:00Z',
      'reg_enddate': '2026-11-27T18:30:00+00:00',
    });
    expect(devFest.eventDateTime.isUtc, isFalse);
    expect(devFest.eventDateTime.toUtc(), DateTime.utc(2026, 11, 28, 3, 30));
    // The phone's own clock and calendar, wherever it is.
    expect(devFest.eventDateTime, DateTime.utc(2026, 11, 28, 3, 30).toLocal());
    expect(devFest.regStartDate.isUtc, isFalse);
    expect(devFest.regStartDate.toUtc(), DateTime.utc(2026, 10));
    expect(devFest.regEndDate!.isUtc, isFalse);
    expect(devFest.regEndDate!.toUtc(), DateTime.utc(2026, 11, 27, 18, 30));
  });

  test('in India: 9:00 AM on the 28th, and 2 AM is not the day before', () {
    DateTime at(String s) =>
        EventInfo.fromJson({'event_datetime': s}).eventDateTime;
    final nine = at('2026-11-28T09:00:00+05:30');
    expect((nine.hour, nine.minute, nine.day), (9, 0, 28));
    // 20:30 UTC on the 27th.
    final two = at('2026-11-28T02:00:00+05:30');
    expect((two.hour, two.day, two.month), (2, 28, 11));
    final zulu = at('2026-11-27T20:30:00Z');
    expect((zulu.hour, zulu.day), (2, 28));
  }, skip: _inIndia ? false : _india);

  test('is_paid and registration_id, when the server sends them', () {
    final unpaid = EventInfo.fromJson({
      'is_registered': true,
      'is_paid': false,
      'registration_id': 'b6f1c2d4-0000-4000-8000-000000000001',
    });
    expect(unpaid.isPaid, isFalse);
    expect(unpaid.registrationId, 'b6f1c2d4-0000-4000-8000-000000000001');

    final notRegistered =
        EventInfo.fromJson({'is_paid': null, 'registration_id': null});
    expect(notRegistered.isPaid, isNull);
    expect(notRegistered.registrationId, isNull);

    // An older server sends neither.
    final older = EventInfo.fromJson({'is_registered': true});
    expect(older.isPaid, isNull);
    expect(older.registrationId, isNull);

    expect(EventInfo.fromJson({'registration_id': ''}).registrationId, isNull);
  });

  test("a club's logo: the dict, an older row's bare URL, or none", () {
    final dict = EventInfo.fromJson({
      'club': {
        'id': 1,
        'logo': {'thumbnail': 'https://x/t.png', 'large': 'https://x/l.png'},
      },
    });
    expect(dict.club.logo['thumbnail'], 'https://x/t.png');

    final bare = EventInfo.fromJson({
      'club': {'id': 1, 'logo': 'https://x/old.png'},
    });
    expect(bare.club.logo['thumbnail'], 'https://x/old.png');

    expect(EventInfo.fromJson({'club': {'id': 1, 'logo': null}}).club.logo,
        isEmpty);
    // An event whose club is gone.
    expect(EventInfo.fromJson({'club': null}).club.id, 0);
  });
}
