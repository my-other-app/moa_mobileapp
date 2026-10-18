import 'package:finnet/common/models/events/event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no reg_enddate is no deadline, not "now"', () {
    expect(EventInfo.fromJson({'reg_enddate': null}).regEndDate, isNull);
    expect(EventInfo.fromJson({}).regEndDate, isNull);
    expect(
      EventInfo.fromJson({'reg_enddate': '2030-01-01T00:00:00Z'}).regEndDate,
      DateTime.utc(2030),
    );
  });

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
}
