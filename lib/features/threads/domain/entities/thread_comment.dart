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

  /// Whether the club itself wrote it -- shown with a "Club" badge.
  final bool isClub;
  final DateTime createdAt;

  const ThreadComment({
    required this.id,
    required this.body,
    this.authorId,
    required this.authorName,
    this.isClub = false,
    required this.createdAt,
  });

  /// Whether [userId] wrote this, and so may delete it.
  ///
  /// The server is the judge -- it refuses anyone else's delete -- this only
  /// decides whether to offer the button.
  bool isBy(int? userId) => userId != null && authorId == userId;

  @override
  List<Object?> get props => [id, body, authorId, authorName, isClub, createdAt];
}
