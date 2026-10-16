import 'package:finnet/features/threads/data/models/thread_models.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:flutter_test/flutter_test.dart';

/// A post exactly as `ThreadOut` serialises it.
Map<String, dynamic> _threadJson({Map<String, dynamic> overrides = const {}}) {
  return {
    'id': '7d0f3c2a-1111-4c4c-9a9a-000000000001',
    'club': {
      'id': 5,
      'name': 'Tinkerhub CET',
      'slug': 'tinkerhub-cet',
      'logo': {
        'original': 'https://cdn.test/logo.png',
        'medium': 'https://cdn.test/logo.medium.png',
        'thumbnail': 'https://cdn.test/logo.thumbnail.png',
      },
    },
    'body': 'Which night works for the build sprint?',
    'image': null,
    'kind': 'poll',
    'poll': {
      'options': [
        {'id': 'a', 'label': 'Friday', 'votes': 3, 'share': 75},
        {'id': 'b', 'label': 'Saturday', 'votes': 1, 'share': 25},
      ],
      'votes': 4,
      'voted_option_id': 'a',
    },
    'pinned': true,
    'notify_followers': true,
    'likes': 12,
    'comments': 4,
    'views': 90,
    'liked': true,
    'created_at': '2026-10-16T08:00:00+00:00',
    ...overrides,
  };
}

void main() {
  group('ThreadModel', () {
    test('reads every field of a full post', () {
      final thread = ThreadModel.fromJson(_threadJson()).toEntity();

      expect(thread.id, '7d0f3c2a-1111-4c4c-9a9a-000000000001');
      expect(thread.club.id, 5);
      expect(thread.club.name, 'Tinkerhub CET');
      expect(thread.club.slug, 'tinkerhub-cet');
      expect(thread.club.logoUrl, 'https://cdn.test/logo.thumbnail.png');
      expect(thread.body, 'Which night works for the build sprint?');
      expect(thread.imageUrl, isNull);
      expect(thread.kind, ThreadKind.poll);
      expect(thread.hasPoll, isTrue);
      expect(thread.poll!.options.map((o) => o.label), ['Friday', 'Saturday']);
      expect(thread.poll!.options.first.share, 75);
      expect(thread.poll!.votes, 4);
      expect(thread.poll!.votedOptionId, 'a');
      expect(thread.pinned, isTrue);
      expect(thread.likes, 12);
      expect(thread.comments, 4);
      expect(thread.views, 90);
      expect(thread.liked, isTrue);
      expect(thread.createdAt.toUtc(), DateTime.utc(2026, 10, 16, 8));
    });

    test('an empty object parses to safe defaults instead of throwing', () {
      // Missing keys must cost a field, never the post -- a throw inside
      // fromJson would take the whole list down with it.
      final thread = ThreadModel.fromJson(const {}).toEntity();

      expect(thread.id, '');
      expect(thread.club.name, '');
      expect(thread.club.logoUrl, isNull);
      expect(thread.body, '');
      expect(thread.kind, ThreadKind.post);
      expect(thread.poll, isNull);
      expect(thread.hasPoll, isFalse);
      expect(thread.pinned, isFalse);
      expect(thread.likes, 0);
      expect(thread.comments, 0);
      expect(thread.liked, isFalse);
      // A missing timestamp reads as now, so the card says "just now".
      expect(
        DateTime.now().difference(thread.createdAt).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('nulls and wrong types are survived field by field', () {
      final thread = ThreadModel.fromJson(_threadJson(overrides: {
        'club': {'id': '5', 'name': null, 'logo': 'not-a-dict'},
        'likes': 3.0,
        'comments': null,
        'liked': null,
        'pinned': 'yes',
        'poll': 'nonsense',
        'image': 42,
        'created_at': 'yesterday-ish',
      })).toEntity();

      expect(thread.club.id, 5);
      expect(thread.club.name, '');
      // A bare URL string is accepted as the logo.
      expect(thread.club.logoUrl, 'not-a-dict');
      expect(thread.likes, 3);
      expect(thread.comments, 0);
      expect(thread.liked, isFalse);
      expect(thread.pinned, isFalse);
      expect(thread.poll, isNull);
      expect(thread.imageUrl, isNull);
    });

    test('the image dict yields the medium URL for the card', () {
      final thread = ThreadModel.fromJson(_threadJson(overrides: {
        'image': {
          'original': 'https://cdn.test/p.png',
          'medium': 'https://cdn.test/p.medium.png',
          'thumbnail': 'https://cdn.test/p.thumbnail.png',
        },
      })).toEntity();

      expect(thread.imageUrl, 'https://cdn.test/p.medium.png');
    });

    test('an image dict with only an original still shows', () {
      final thread = ThreadModel.fromJson(_threadJson(overrides: {
        'image': {'original': 'https://cdn.test/p.png'},
      })).toEntity();

      expect(thread.imageUrl, 'https://cdn.test/p.png');
    });

    test('an image dict with no usable URL is no image', () {
      final thread = ThreadModel.fromJson(_threadJson(overrides: {
        'image': {'original': '', 'thumbnail': null},
      })).toEntity();

      expect(thread.image, isNull);
      expect(thread.imageUrl, isNull);
    });

    test('a negative count is read as zero', () {
      final thread = ThreadModel.fromJson(
        _threadJson(overrides: {'likes': -2}),
      ).toEntity();

      expect(thread.likes, 0);
    });
  });

  group('PollModel', () {
    test('a fresh poll with no vote reads voted_option_id as null', () {
      final poll = PollModel.fromJson(const {
        'options': [
          {'id': 'a', 'label': 'Yes', 'votes': 0, 'share': 0},
        ],
        'votes': 0,
        'voted_option_id': null,
      }).toEntity();

      expect(poll.hasVoted, isFalse);
      expect(poll.options.single.label, 'Yes');
    });

    test('options without an id are dropped -- they cannot be voted for', () {
      final poll = PollModel.fromJson(const {
        'options': [
          {'label': 'Orphan', 'votes': 2},
          {'id': 'b', 'label': 'Real', 'votes': 1, 'share': 100},
          'not a map',
        ],
      }).toEntity();

      expect(poll.options.map((o) => o.id), ['b']);
    });

    test('a missing total is summed from the options', () {
      final poll = PollModel.fromJson(const {
        'options': [
          {'id': 'a', 'label': 'A', 'votes': 2, 'share': 67},
          {'id': 'b', 'label': 'B', 'votes': 1, 'share': 33},
        ],
      }).toEntity();

      expect(poll.votes, 3);
    });

    test('a share outside 0-100 is clamped rather than overflowing the bar',
        () {
      final poll = PollModel.fromJson(const {
        'options': [
          {'id': 'a', 'label': 'A', 'votes': 2, 'share': 140},
        ],
      }).toEntity();

      expect(poll.options.single.share, 100);
    });

    test('a poll with no options is not drawn as a poll', () {
      final thread = ThreadModel.fromJson(_threadJson(overrides: {
        'kind': 'post',
        'poll': {'options': [], 'votes': 0},
      })).toEntity();

      expect(thread.hasPoll, isFalse);
      expect(thread.kind, ThreadKind.post);
    });
  });

  group('Poll.withVote, the optimistic half of a vote', () {
    const poll = Poll(
      options: [
        PollOption(id: 'a', label: 'A', votes: 3, share: 75),
        PollOption(id: 'b', label: 'B', votes: 1, share: 25),
      ],
      votes: 4,
    );

    test('a first vote adds one and marks the choice', () {
      final voted = poll.withVote('b');

      expect(voted.votes, 5);
      expect(voted.votedOptionId, 'b');
      expect(voted.options.map((o) => o.votes), [3, 2]);
      expect(voted.options.map((o) => o.share), [60, 40]);
    });

    test('voting again moves the vote; the total stays', () {
      final moved = poll.withVote('b').withVote('a');

      expect(moved.votes, 5);
      expect(moved.votedOptionId, 'a');
      expect(moved.options.map((o) => o.votes), [4, 1]);
    });

    test('voting for the current choice changes nothing', () {
      final voted = poll.withVote('a');
      expect(voted.withVote('a'), voted);
    });

    test('an option not on the poll changes nothing', () {
      expect(poll.withVote('zzz'), poll);
    });
  });

  group('ThreadPageModel', () {
    test('reads the items envelope and knows whether more remain', () {
      final page = ThreadPageModel.fromJson({
        'items': [_threadJson()],
        'total': 3,
        'limit': 1,
        'offset': 0,
      }).toEntity(requestedOffset: 0, requestedLimit: 1);

      expect(page.items, hasLength(1));
      expect(page.total, 3);
      expect(page.hasMore, isTrue);
    });

    test('the last page says so', () {
      final page = ThreadPageModel.fromJson({
        'items': [_threadJson()],
        'total': 21,
        'limit': 20,
        'offset': 20,
      }).toEntity(requestedOffset: 20, requestedLimit: 20);

      expect(page.hasMore, isFalse);
    });

    test('a null body is an empty last page, not a crash', () {
      final page = ThreadPageModel.fromJson(null)
          .toEntity(requestedOffset: 0, requestedLimit: 20);

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('posts without an id are dropped', () {
      final page = ThreadPageModel.fromJson({
        'items': [
          _threadJson(),
          _threadJson(overrides: {'id': null}),
        ],
        'total': 2,
      }).toEntity(requestedOffset: 0, requestedLimit: 20);

      expect(page.items, hasLength(1));
    });

    test('a results-shaped body yields nothing, as elsewhere in the app', () {
      final page = ThreadPageModel.fromJson({
        'results': [_threadJson()],
      }).toEntity(requestedOffset: 0, requestedLimit: 20);

      expect(page.items, isEmpty);
    });
  });

  group('ThreadCommentModel', () {
    test('reads a follower comment', () {
      final comment = ThreadCommentModel.fromJson(const {
        'id': 'c1',
        'body': 'Count me in',
        'author': {'id': 42, 'name': 'Aarav', 'is_club': false},
        'created_at': '2026-10-16T09:00:00Z',
      }).toEntity();

      expect(comment.id, 'c1');
      expect(comment.body, 'Count me in');
      expect(comment.authorId, 42);
      expect(comment.authorName, 'Aarav');
      expect(comment.isClub, isFalse);
      expect(comment.isBy(42), isTrue);
      expect(comment.isBy(7), isFalse);
      expect(comment.isBy(null), isFalse);
    });

    test('reads the club replying as itself', () {
      final comment = ThreadCommentModel.fromJson(const {
        'id': 'c2',
        'body': 'See you there',
        'author': {'id': 9, 'name': 'Tinkerhub CET', 'is_club': true},
        'created_at': '2026-10-16T09:00:00Z',
      }).toEntity();

      expect(comment.isClub, isTrue);
    });

    test('a missing author is a nameless follower nobody can delete', () {
      final comment = ThreadCommentModel.fromJson(const {
        'id': 'c3',
        'body': 'hi',
      }).toEntity();

      expect(comment.authorName, 'A follower');
      expect(comment.authorId, isNull);
      expect(comment.isClub, isFalse);
      expect(comment.isBy(null), isFalse);
    });
  });

  group('LikeResultModel', () {
    test('reads where the like settled', () {
      final result =
          LikeResultModel.fromJson(const {'liked': true, 'likes': 13})
              .toEntity();

      expect(result, const LikeResult(liked: true, likes: 13));
    });

    test('a null body reads as not liked, zero', () {
      expect(
        LikeResultModel.fromJson(null).toEntity(),
        const LikeResult(liked: false, likes: 0),
      );
    });
  });
}
