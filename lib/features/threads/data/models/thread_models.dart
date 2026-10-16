import 'dart:math' as math;

import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    show ImageUrls;
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';

// --- Defensive readers --------------------------------------------------------
//
// Every field is read as "this, if it is what we expect, else a default".
// A bare `as int` throws on a missing key or on 4.0-for-4, and a throw inside
// fromJson loses the whole post rather than one field -- the same failure that
// once hid every club logo (see model_number_parsing_test.dart).

int? _int(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// A count: never negative, zero when absent.
int _count(dynamic value) => math.max(0, _int(value) ?? 0);

String? _str(dynamic value) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

bool _bool(dynamic value) => value is bool ? value : value == 'true';

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

/// A server timestamp in local time. A missing or malformed one reads as
/// "now", so the card says "just now" instead of the list failing.
DateTime _date(dynamic value) =>
    DateTime.tryParse(_str(value) ?? '')?.toLocal() ?? DateTime.now();

/// An S3 image dict -- `{original, medium, thumbnail, large}` -- as the
/// app's [ImageUrls]. Null when there is no usable URL in it at all.
ImageUrls? _image(dynamic value) {
  // Older rows sometimes carry a bare URL rather than the dict.
  if (value is String) {
    return value.isEmpty ? null : ImageUrls(original: value);
  }
  final map = _map(value);
  if (map == null) return null;
  String? url(String key) {
    final v = _str(map[key]);
    return (v == null || v.isEmpty) ? null : v;
  }

  final original = url('original') ?? url('large') ?? url('medium');
  final thumbnail = url('thumbnail');
  if (original == null && thumbnail == null) return null;
  return ImageUrls(
    original: original ?? thumbnail!,
    medium: url('medium'),
    thumbnail: thumbnail,
  );
}

// --- Models -------------------------------------------------------------------

/// The `club` object on a post: `{id, name, slug, logo}`.
class ThreadClubModel {
  final int id;
  final String name;
  final String? slug;
  final ImageUrls? logo;

  const ThreadClubModel({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
  });

  factory ThreadClubModel.fromJson(Map<String, dynamic>? json) {
    return ThreadClubModel(
      id: _int(json?['id']) ?? 0,
      name: _str(json?['name']) ?? '',
      slug: _str(json?['slug']),
      logo: _image(json?['logo']),
    );
  }

  ThreadClub toEntity() =>
      ThreadClub(id: id, name: name, slug: slug, logo: logo);
}

/// One option on a poll: `{id, label, votes, share}`.
class PollOptionModel {
  final String id;
  final String label;
  final int votes;
  final int share;

  const PollOptionModel({
    required this.id,
    required this.label,
    this.votes = 0,
    this.share = 0,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: _str(json['id']) ?? '',
      label: _str(json['label']) ?? '',
      votes: _count(json['votes']),
      share: math.min(100, _count(json['share'])),
    );
  }

  PollOption toEntity() =>
      PollOption(id: id, label: label, votes: votes, share: share);
}

/// `PollOut`: `{options, votes, voted_option_id}`.
class PollModel {
  final List<PollOptionModel> options;
  final int? votes;
  final String? votedOptionId;

  const PollModel({
    this.options = const [],
    this.votes,
    this.votedOptionId,
  });

  factory PollModel.fromJson(Map<String, dynamic>? json) {
    final voted = _str(json?['voted_option_id']);
    return PollModel(
      options: _maps(json?['options'])
          .map(PollOptionModel.fromJson)
          // An option without an id cannot be voted for.
          .where((o) => o.id.isNotEmpty)
          .toList(),
      votes: _int(json?['votes']),
      votedOptionId: (voted == null || voted.isEmpty) ? null : voted,
    );
  }

  Poll toEntity() => Poll(
        options: options.map((o) => o.toEntity()).toList(),
        // Summed when absent rather than shown as "0 votes" beside bars that
        // plainly have some.
        votes: math.max(
            0, votes ?? options.fold<int>(0, (sum, o) => sum + o.votes)),
        votedOptionId: votedOptionId,
      );
}

/// `ThreadOut`.
class ThreadModel {
  final String id;
  final ThreadClubModel club;
  final String body;
  final ImageUrls? image;
  final String? kind;
  final PollModel? poll;
  final bool pinned;
  final int likes;
  final int comments;
  final int views;
  final bool liked;
  final DateTime createdAt;

  const ThreadModel({
    required this.id,
    required this.club,
    required this.body,
    this.image,
    this.kind,
    this.poll,
    this.pinned = false,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.liked = false,
    required this.createdAt,
  });

  factory ThreadModel.fromJson(Map<String, dynamic> json) {
    final poll = _map(json['poll']);
    return ThreadModel(
      id: _str(json['id']) ?? '',
      club: ThreadClubModel.fromJson(_map(json['club'])),
      body: _str(json['body']) ?? '',
      image: _image(json['image']),
      kind: _str(json['kind']),
      poll: poll == null ? null : PollModel.fromJson(poll),
      pinned: _bool(json['pinned']),
      likes: _count(json['likes']),
      comments: _count(json['comments']),
      views: _count(json['views']),
      liked: _bool(json['liked']),
      createdAt: _date(json['created_at']),
    );
  }

  Thread toEntity() {
    final parsedPoll = poll?.toEntity();
    return Thread(
      id: id,
      club: club.toEntity(),
      body: body,
      image: image,
      // Options decide it as much as the label: a poll is drawn as one when
      // there is something to vote on.
      kind: kind == 'poll' || (parsedPoll?.options.isNotEmpty ?? false)
          ? ThreadKind.poll
          : ThreadKind.post,
      poll: parsedPoll,
      pinned: pinned,
      likes: likes,
      comments: comments,
      views: views,
      liked: liked,
      createdAt: createdAt,
    );
  }
}

/// The paginated envelope: `{items, total, limit, offset}`.
class ThreadPageModel {
  final List<ThreadModel> items;
  final int? total;
  final int? limit;
  final int? offset;

  const ThreadPageModel({
    this.items = const [],
    this.total,
    this.limit,
    this.offset,
  });

  /// The list is under `items` -- `ThreadPage` in the backend's schemas,
  /// the same envelope as every other paginated route.
  factory ThreadPageModel.fromJson(Map<String, dynamic>? json) {
    return ThreadPageModel(
      items: _maps(json?['items'])
          .map(ThreadModel.fromJson)
          // A post without an id cannot be opened, liked or voted on.
          .where((t) => t.id.isNotEmpty)
          .toList(),
      total: _int(json?['total']),
      limit: _int(json?['limit']),
      offset: _int(json?['offset']),
    );
  }

  ThreadPage toEntity({
    required int requestedOffset,
    required int requestedLimit,
  }) {
    final start = offset ?? requestedOffset;
    final count = items.length;
    return ThreadPage(
      items: items.map((t) => t.toEntity()).toList(),
      // With no total, a full page means "maybe more" and a short one means
      // "that was the end"; one extra request settles the first case.
      total: total ??
          (count >= requestedLimit ? start + count + 1 : start + count),
      limit: limit ?? requestedLimit,
      offset: start,
    );
  }
}

/// `CommentOut`: `{id, body, author: {id, name, is_club}, created_at}`.
class ThreadCommentModel {
  final String id;
  final String body;
  final int? authorId;
  final String authorName;
  final bool isClub;
  final DateTime createdAt;

  const ThreadCommentModel({
    required this.id,
    required this.body,
    this.authorId,
    required this.authorName,
    this.isClub = false,
    required this.createdAt,
  });

  factory ThreadCommentModel.fromJson(Map<String, dynamic> json) {
    final author = _map(json['author']);
    final name = (_str(author?['name']) ?? '').trim();
    return ThreadCommentModel(
      id: _str(json['id']) ?? '',
      body: _str(json['body']) ?? '',
      authorId: _int(author?['id']),
      // The server's own fallback for a follower with no name.
      authorName: name.isEmpty ? 'A follower' : name,
      isClub: _bool(author?['is_club']),
      createdAt: _date(json['created_at']),
    );
  }

  ThreadComment toEntity() => ThreadComment(
        id: id,
        body: body,
        authorId: authorId,
        authorName: authorName,
        isClub: isClub,
        createdAt: createdAt,
      );
}

/// `{liked, likes}` from the like toggle.
class LikeResultModel {
  final bool liked;
  final int likes;

  const LikeResultModel({required this.liked, required this.likes});

  factory LikeResultModel.fromJson(Map<String, dynamic>? json) {
    return LikeResultModel(
      liked: _bool(json?['liked']),
      likes: _count(json?['likes']),
    );
  }

  LikeResult toEntity() => LikeResult(liked: liked, likes: likes);
}
