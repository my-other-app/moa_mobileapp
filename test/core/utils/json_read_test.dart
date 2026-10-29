import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the readers', () {
    test('take what can be read, and answer null for the rest', () {
      expect(jsonInt(3), 3);
      expect(jsonInt(3.0), 3);
      expect(jsonInt('12'), 12);
      expect(jsonInt('x'), isNull);
      expect(jsonInt(null), isNull);
      expect(jsonDouble(4), 4.0);
      expect(jsonDouble('4.5'), 4.5);
      expect(jsonString(7), '7');
      expect(jsonString({'a': 1}), isNull);
      expect(jsonText(null, 'none'), 'none');
      expect(jsonBool(1), isTrue);
      expect(jsonBool('false'), isFalse);
      expect(jsonBool('maybe'), isNull);
      expect(jsonObject({1: 'a'}), {'1': 'a'});
      expect(jsonObject('x'), isNull);
      expect(jsonObjects([{'a': 1}, 'junk', 3, null]), [
        {'a': 1}
      ]);
      expect(jsonObjects('x'), isEmpty);
      // The same moment, on the phone's clock.
      expect(jsonDate('2026-10-19T10:00:00Z')!.toUtc(),
          DateTime.utc(2026, 10, 19, 10));
      expect(jsonDate('2026-10-19T10:00:00Z')!.isUtc, isFalse);
      expect(jsonDate(42), isNull);
    });
  });

  group('models no longer throw on a field of the wrong shape', () {
    test('a notification with a string user id and no dates', () {
      final n = NotificationModel.fromJson({
        'id': 99,
        'user_id': '12',
        'title': 'Hello',
        'type': 'club_announcement',
        'status': 'unread',
        'from_club': {'id': '5', 'name': 'Tinkerhub', 'logo': 42},
        'event': 'not an object',
        'data': ['not', 'a', 'map'],
      });
      expect(n.id, '99');
      expect(n.userId, 12);
      expect(n.fromClub!.id, 5);
      expect(n.fromClub!.logo, isNull);
      expect(n.event, isNull);
      expect(n.data, isNull);
    });

    test('a profile with a string id and odd nesting', () {
      final p = UserProfileModel.fromJson({
        'id': '7',
        'full_name': 'Ana',
        'email': 'a@b.c',
        'profile': {'org': 'not a map', 'avatar': null, 'whatsapp': 9876543210},
        'interests': [
          {'id': 1, 'name': 'Flutter'},
          'junk',
        ],
        'email_verified': 1,
      });
      expect(p.id, 7);
      expect(p.profile!.org, isNull);
      expect(p.profile!.whatsapp, '9876543210');
      expect(p.interests, hasLength(1));
      expect(p.emailVerified, isTrue);
    });

    test('an event with a bare poster URL, a string fee and junk lists', () {
      final e = EventInfo.fromJson({
        'id': '7',
        'name': 'Hack',
        'poster': 'https://img/p.jpg',
        'reg_fee': '250',
        'has_fee': 'true',
        'category': 'Tech',
        'club': null,
        'interests': 'none',
        'additional_details': [
          {'key': 'roll', 'label': 'Roll no', 'field_type': 'text', 'required': 1},
          7,
        ],
        'downloads': null,
      });
      expect(e.id, 7);
      expect(e.poster, {'original': 'https://img/p.jpg'});
      expect(e.regFee, 250);
      expect(e.hasFee, isTrue);
      expect(e.category.name, '');
      expect(e.interests, isEmpty);
      expect(e.additionalDetails.single.requiredField, isTrue);
    });

    test('a certificate from a row with a numeric ticket id', () {
      final c = Certificate.fromEventJson({
        'id': '3',
        'name': 'Talk',
        'ticket_id': 'MOA-1',
        'is_attended': true,
        'club': {'name': 42},
        'category': 'odd',
      });
      expect(c, isNotNull);
      expect(c!.eventId, 3);
      expect(c.clubName, '42');
      expect(c.eventType, isNull);
    });
  });
}
