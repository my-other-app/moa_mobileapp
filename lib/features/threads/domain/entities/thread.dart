import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    show ImageUrls;

/// What a club post is: plain text (maybe with a photo), or a question with
/// options to vote on.
enum ThreadKind { post, poll }

/// The club a post belongs to, as much of it as the card needs.
class ThreadClub extends Equatable {
  final int id;
  final String name;
  final String? slug;
  final ImageUrls? logo;

  const ThreadClub({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
  });

  /// The smallest usable logo URL, or null when the club has none.
  String? get logoUrl {
    final url = logo?.thumbnailUrl;
    return (url == null || url.isEmpty) ? null : url;
  }

  @override
  List<Object?> get props => [id, name, slug, logo];
}

/// One answer on a poll.
class PollOption extends Equatable {
  final String id;
  final String label;
  final int votes;

  /// Percent of all votes, 0-100, as the server rounds it.
  final int share;

  const PollOption({
    required this.id,
    required this.label,
    this.votes = 0,
    this.share = 0,
  });

  PollOption copyWith({int? votes, int? share}) => PollOption(
        id: id,
        label: label,
        votes: votes ?? this.votes,
        share: share ?? this.share,
      );

  @override
  List<Object?> get props => [id, label, votes, share];
}

/// A poll's options and where the votes stand.
class Poll extends Equatable {
  final List<PollOption> options;

  /// Total votes cast.
  final int votes;

  /// The option this person chose, or null if they have not voted.
  final String? votedOptionId;

  const Poll({
    this.options = const [],
    this.votes = 0,
    this.votedOptionId,
  });

  bool get hasVoted => votedOptionId != null;

  /// The poll as it will look once [optionId] holds this person's vote.
  ///
  /// Used for the optimistic update before the server answers. One vote per
  /// person, and voting again moves it -- so a previous choice loses the vote
  /// the new one gains, and the total only grows on a first vote. Shares are
  /// recomputed locally; the server's answer replaces them a moment later.
  Poll withVote(String optionId) {
    if (votedOptionId == optionId) return this;
    if (!options.any((o) => o.id == optionId)) return this;

    final moved = [
      for (final o in options)
        if (o.id == optionId)
          o.copyWith(votes: o.votes + 1)
        else if (o.id == votedOptionId)
          o.copyWith(votes: math.max(0, o.votes - 1))
        else
          o,
    ];
    final total = moved.fold<int>(0, (sum, o) => sum + o.votes);
    return Poll(
      options: [
        for (final o in moved)
          o.copyWith(share: total == 0 ? 0 : (o.votes * 100 / total).round()),
      ],
      votes: total,
      votedOptionId: optionId,
    );
  }

  @override
  List<Object?> get props => [options, votes, votedOptionId];
}

/// A club's post, as a reader sees it.
///
/// Mirrors `ThreadOut` in the backend's `app/api/threads/schemas.py`.
class Thread extends Equatable {
  final String id;
  final ThreadClub club;
  final String body;
  final ImageUrls? image;
  final ThreadKind kind;
  final Poll? poll;
  final bool pinned;
  final int likes;
  final int comments;
  final int views;

  /// Whether this person has liked it.
  final bool liked;
  final DateTime createdAt;

  const Thread({
    required this.id,
    required this.club,
    required this.body,
    this.image,
    this.kind = ThreadKind.post,
    this.poll,
    this.pinned = false,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.liked = false,
    required this.createdAt,
  });

  /// The image URL to show on a card, or null when there is no image.
  String? get imageUrl {
    final url = image?.mediumUrl;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// Whether there is a poll worth drawing. A poll with no options -- a
  /// malformed response -- is drawn as a plain post rather than an empty box.
  bool get hasPoll => poll != null && poll!.options.isNotEmpty;

  Thread copyWith({
    Poll? poll,
    bool? liked,
    int? likes,
    int? comments,
  }) {
    return Thread(
      id: id,
      club: club,
      body: body,
      image: image,
      kind: kind,
      poll: poll ?? this.poll,
      pinned: pinned,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      views: views,
      liked: liked ?? this.liked,
      createdAt: createdAt,
    );
  }

  /// The post as it will look once the like is toggled -- the optimistic
  /// half of a like. The server's [LikeResult] settles it.
  Thread withLikeToggled() => copyWith(
        liked: !liked,
        likes: math.max(0, likes + (liked ? -1 : 1)),
      );

  @override
  List<Object?> get props => [
        id,
        club,
        body,
        image,
        kind,
        poll,
        pinned,
        likes,
        comments,
        views,
        liked,
        createdAt,
      ];
}

/// One page of posts.
class ThreadPage extends Equatable {
  final List<Thread> items;
  final int total;
  final int limit;
  final int offset;

  /// The cursor for the page after this one, on the lists that page by
  /// cursor (the follower's feed: its `offset` is always 0 there, so only
  /// this says whether there is more). Null on the last page.
  final String? nextCursor;

  const ThreadPage({
    this.items = const [],
    this.total = 0,
    this.limit = 20,
    this.offset = 0,
    this.nextCursor,
  });

  /// Whether another page exists after this one.
  ///
  /// An empty page ends the list whatever `total` says, so a stale total can
  /// never leave the list asking for more forever.
  bool get hasMore => items.isNotEmpty && offset + items.length < total;

  @override
  List<Object?> get props => [items, total, limit, offset, nextCursor];
}

/// What the server says after a like is toggled.
class LikeResult extends Equatable {
  final bool liked;
  final int likes;

  const LikeResult({required this.liked, required this.likes});

  @override
  List<Object?> get props => [liked, likes];
}
