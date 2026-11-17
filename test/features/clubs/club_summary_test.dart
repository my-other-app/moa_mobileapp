import 'package:finnet/features/clubs/domain/club_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a club row, read whole', () {
    final club = ClubSummary.fromJson({
      'id': 5,
      'name': 'Tinkerhub CET',
      'slug': 'tinkerhub-cet',
      'logo': {'thumbnail': 'https://img/t.png', 'medium': 'https://img/m.png'},
      'followers_count': 120,
      'interests': [
        {'id': 1, 'name': 'AI'},
        {'id': 2, 'name': 'Robotics'},
      ],
      'is_following': true,
      'is_pinned': false,
      'is_hidden': false,
    })!;

    expect(club.id, 5);
    expect(club.name, 'Tinkerhub CET');
    expect(club.slug, 'tinkerhub-cet');
    expect(club.logoUrl, 'https://img/t.png');
    expect(club.followersCount, 120);
    expect(club.interests, ['AI', 'Robotics']);
    expect(club.isFollowing, isTrue);
  });

  test('odd fields are defaults, never a crash', () {
    final club = ClubSummary.fromJson({
      'id': '7',
      'name': null,
      'slug': 3,
      'logo': '',
      'followers_count': '12',
      'interests': [
        'AI',
        {'name': null},
        {'name': 'Music'},
      ],
      'is_following': null,
      'is_pinned': 1,
      'is_hidden': 'false',
    })!;

    expect(club.id, 7);
    expect(club.name, '');
    expect(club.slug, '3');
    expect(club.logoUrl, isNull);
    expect(club.followersCount, 12);
    expect(club.interests, ['Music']);
    expect(club.isFollowing, isFalse);
    expect(club.isPinned, isTrue);
    expect(club.isHidden, isFalse);
  });

  test('a row without an id is no club; a list skips it', () {
    expect(ClubSummary.fromJson({'name': 'x'}), isNull);
    expect(ClubSummary.fromJson({'id': 0}), isNull);
    expect(ClubSummary.fromJson('club'), isNull);
    expect(
        ClubSummary.listFrom([
          {'id': 1, 'name': 'A'},
          {'name': 'B'},
          null,
          {'id': 3, 'name': 'C'},
        ]).map((c) => c.name),
        ['A', 'C']);
    expect(ClubSummary.listFrom({'items': []}), isEmpty);
  });

  test('pinned is the one thing marked afterwards', () {
    final club = ClubSummary.fromJson({'id': 1, 'name': 'A'})!;
    final pinned = club.copyWith(isPinned: true);
    expect(pinned.isPinned, isTrue);
    expect(pinned.copyWith(isPinned: false), club);
  });
}
