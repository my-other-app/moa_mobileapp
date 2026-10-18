import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// One row of `GET /user/blocks`: `{user_id, name, avatar}`.
///
/// Read defensively, like the rest of this feature's models: a row without
/// a usable id is dropped by the caller rather than thrown on, since it
/// could never be unblocked.
class BlockedUserModel {
  final int? userId;
  final String name;
  final String? avatarUrl;

  const BlockedUserModel({this.userId, required this.name, this.avatarUrl});

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['user_id'] ?? json['id'];
    final id = rawId is num
        ? rawId.toInt()
        : (rawId is String ? int.tryParse(rawId) : null);
    final name = json['name'] is String ? (json['name'] as String).trim() : '';
    return BlockedUserModel(
      userId: (id == null || id <= 0) ? null : id,
      name: name.isEmpty ? 'A follower' : name,
      // A URL, or the S3 dict every other image arrives as.
      avatarUrl: imageUrlFrom(json['avatar']),
    );
  }

  BlockedUser toEntity() =>
      BlockedUser(userId: userId ?? 0, name: name, avatarUrl: avatarUrl);
}

/// The body of `POST /reports`.
///
/// `target_id` goes as a number when it is one (users, clubs) and as the
/// string otherwise: posts and comments have UUID ids.
Map<String, dynamic> reportRequestBody(
  ReportTarget target,
  ReportReason reason, {
  String? note,
}) {
  final trimmed = note?.trim() ?? '';
  return {
    'target_type': target.type.name,
    'target_id': int.tryParse(target.id) ?? target.id,
    'reason': reason.name,
    if (trimmed.isNotEmpty) 'note': trimmed,
  };
}
