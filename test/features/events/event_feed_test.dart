import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eventLengthLabel', () {
    test('formats hours, never "null Hours"', () {
      expect(eventLengthLabel(2), '2 Hours');
      expect(eventLengthLabel(2.5), '2.5 Hours');
      expect(eventLengthLabel(1), '1 Hour');
      expect(eventLengthLabel('3'), '3 Hours');
    });

    test('missing, zero or nonsense is left out', () {
      expect(eventLengthLabel(null), isNull);
      expect(eventLengthLabel(0), isNull);
      expect(eventLengthLabel(-1), isNull);
      expect(eventLengthLabel('soon'), isNull);
    });
  });

  test('tags leave out what is missing', () {
    expect(
      eventCardTags({
        'category': {'name': 'Tech'},
        'is_online': true,
        'has_fee': true,
        'duration': 2.5,
      }),
      ['Tech', 'Online', 'Paid', '2.5 Hours'],
    );
    expect(
      eventCardTags({'duration': null, 'category': null}),
      ['Offline', 'Free'],
    );
  });

  test('an event without its club does not crash the card', () {
    expect(eventClubId({'club': null}), 0);
    expect(eventClubId({}), 0);
    expect(
        eventClubId({
          'club': {'id': 12}
        }),
        12);

    final card = eventCardFromJson({
      'id': 7,
      'name': 'Hack Night',
      'club': null,
      'duration': null,
      'slug': null,
    });
    expect(card.clubId, 0);
    expect(card.eventId, 7);
    expect(card.eventSlug, '');
    expect(card.organizer, 'Unknown Organizer');
    expect(card.tags, isNot(contains(contains('null'))));
    expect(card.status, EventCardStatus.none);
  });

  test('the share link is the event page on the site, by slug or by id', () {
    expect(eventShareUrl(id: 7, slug: 'hack-night'),
        'https://myotherapp.in/events/hack-night');
    expect(eventShareUrl(id: 7, slug: ''), 'https://myotherapp.in/events/7');
    expect(eventShareUrl(id: 7), 'https://myotherapp.in/events/7');
  });
}
