import 'package:finnet/features/clubs/data/models/club_models.dart';
import 'package:finnet/features/events/data/models/event_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON numbers arrive as int or double depending on the value: 4 comes back
/// as int, 4.5 as double. A `as int?` cast throws on the second, and the
/// throw happens inside fromJson -- so the whole object is lost, not just
/// the field.
///
/// That is what hid the club logo. /clubs/info/{id} returns rating 4.5,
/// ClubModel cast it with `as int?`, the parse threw, the repository
/// returned a failure, and the notes tab rendered the club's initial as
/// though the club simply had no logo.
void main() {
  group('ClubModel survives the numbers the server actually sends', () {
    test('a fractional rating does not take the whole club down', () {
      final club = ClubModel.fromJson(const {
        'id': 5,
        'name': 'LetMeGoo',
        'slug': 'letmegoo',
        'rating': 4.5,
        'total_ratings': 2,
        'followers_count': 3,
        'logo': {
          'thumbnail': 'https://example.test/t.png',
          'medium': 'm',
          'large': 'l',
          'original': 'o',
        },
      }).toEntity();

      expect(club.rating, 4.5);
      // The point of the test: the logo survives because the parse does.
      expect(club.logo?.thumbnail, 'https://example.test/t.png');
    });

    test('a whole-number rating still parses', () {
      // The same field arrives as an int when the value is whole, which is
      // why a fixture with `rating: 4` passed while production failed.
      final club = ClubModel.fromJson(const {
        'id': 1,
        'name': 'C',
        'slug': 'c',
        'rating': 4,
      }).toEntity();

      expect(club.rating, 4.0);
    });

    test('total_ratings is read, not total_rating', () {
      // The server sends the plural. Reading the singular yielded null
      // silently -- every club showed zero ratings.
      final club = ClubModel.fromJson(const {
        'id': 1,
        'name': 'C',
        'slug': 'c',
        'total_ratings': 7,
      }).toEntity();

      expect(club.totalRatings, 7);
    });
  });

  group('EventModel survives them too', () {
    test('a fractional duration does not throw', () {
      // events.duration is a Float column and NOT NULL, so `as int?` threw
      // on every event there has ever been.
      final event = EventModel.fromJson(const {
        'id': 7,
        'name': 'Hack Night',
        'slug': 'hack-night',
        'duration': 7.5,
        'event_datetime': '2026-10-11T19:30:00+00:00',
      });

      expect(event.duration, 7.5);
    });

    test('money arrives as a decimal', () {
      // reg_fee and prize_amount are Numeric(10,2).
      final event = EventModel.fromJson(const {
        'id': 7,
        'name': 'E',
        'slug': 'e',
        'duration': 2.0,
        'reg_fee': 250.50,
        'prize_amount': 5000.00,
        'event_datetime': '2026-10-11T19:30:00+00:00',
      });

      expect(event.regFee, 250.50);
      expect(event.prizeAmount, 5000.0);
    });
  });
}
