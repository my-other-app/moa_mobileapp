import 'package:equatable/equatable.dart';

/// A comment under a club's post.
///
/// Mirrors `CommentOut` in the backend's `app/api/threads/schemas.py`.
class ThreadComment extends Equatable {
  final String id;
  final String body;

  /// The author's user id. Null only if the server ever omits it, in which
  /// case nobody can delete the comment from the app.
  final int? authorId;
  final String authorName;

  /// The author's avatar, when the server sends one.
  final String? authorAvatarUrl;

  /// Whether the club itself wrote it -- shown with a "Club" badge.
  final bool isClub;
  final DateTime createdAt;

  const ThreadComment({
    required this.id,
    required this.body,
    this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    this.isClub = false,
    required this.createdAt,
  });

  /// Whether [userId] wrote this, and so may delete it.
  ///
  /// The server is the judge -- it refuses anyone else's delete -- this only
  /// decides whether to offer the button.
  bool isBy(int? userId) => userId != null && authorId == userId;

  /// Whether its author is a person who can be blocked.
  ///
  /// Not the club's own replies -- those speak for the club, which a reader
  /// can unfollow or report -- and not a comment with no author id, which
  /// gives nothing to block.
  bool get authorCanBeBlocked =>
      !isClub && authorId != null && authorId! > 0;

  @override
  List<Object?> get props =>
      [id, body, authorId, authorName, authorAvatarUrl, isClub, createdAt];
}
