import 'package:equatable/equatable.dart';

/// What can be reported: the server's `target_type`.
enum ReportTargetType { thread, comment, user, club }

/// Why something is reported: the server's `reason`.
///
/// The names are the wire values; the words a person picks from live with
/// the sheet that shows them.
enum ReportReason {
  spam,
  harassment,
  hate,
  sexual,
  violence,
  misinformation,
  other,
}

/// The thing being reported.
///
/// [id] is a string because posts and comments have UUID ids while users and
/// clubs have numbers; the data layer sends whichever it is.
class ReportTarget extends Equatable {
  final ReportTargetType type;
  final String id;

  const ReportTarget(this.type, this.id);

  const ReportTarget.thread(String threadId)
      : this(ReportTargetType.thread, threadId);

  const ReportTarget.comment(String commentId)
      : this(ReportTargetType.comment, commentId);

  factory ReportTarget.user(int userId) =>
      ReportTarget(ReportTargetType.user, '$userId');

  @override
  List<Object?> get props => [type, id];
}

/// Someone this person has blocked: their comments are hidden from them.
class BlockedUser extends Equatable {
  final int userId;
  final String name;

  /// A small avatar URL, or null when they have none.
  final String? avatarUrl;

  const BlockedUser({
    required this.userId,
    required this.name,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [userId, name, avatarUrl];
}
