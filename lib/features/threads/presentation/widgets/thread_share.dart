import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:share_plus/share_plus.dart';

/// A post's page on the website: `https://myotherapp.in/threads/{id}`,
/// which anyone can open, app or no app.
String threadShareUrl(String threadId) =>
    '${AppConfig.publicSiteUrl}/threads/${Uri.encodeComponent(threadId)}';

/// What sharing a post sends: the start of what it says, then whose it is
/// and where to read the rest.
String threadShareText(Thread thread) {
  final url = threadShareUrl(thread.id);
  final club = thread.club.name.trim().isEmpty ? 'A club' : thread.club.name;
  final firstLine = thread.body
      .trim()
      .split('\n')
      .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '')
      .trim();
  final snippet = firstLine.length > 120
      ? '${firstLine.substring(0, 117).trimRight()}…'
      : firstLine;
  return snippet.isEmpty
      ? '$club on MyOtherApp: $url'
      : '$snippet\n\n$club on MyOtherApp: $url';
}

/// Hands text to the phone's share sheet. A provider so a test can see what
/// would have been shared without the platform.
typedef ThreadSharer = Future<void> Function(
  String text, {
  String? subject,
  Rect? origin,
});

Future<void> _systemShare(String text, {String? subject, Rect? origin}) =>
    Share.share(text, subject: subject, sharePositionOrigin: origin);

final threadSharerProvider = Provider<ThreadSharer>((ref) => _systemShare);

/// Share [thread] from the button at [buttonContext], which the sheet points
/// at on an iPad (it needs somewhere to point, or it throws).
Future<void> shareThread(
  BuildContext buttonContext,
  WidgetRef ref,
  Thread thread,
) async {
  final box = buttonContext.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final club = thread.club.name.trim();
  try {
    await ref.read(threadSharerProvider)(
      threadShareText(thread),
      subject: club.isEmpty ? null : 'A post from $club',
      origin: origin,
    );
  } catch (e) {
    debugPrint('Thread share failed: $e');
    if (!buttonContext.mounted) return;
    ScaffoldMessenger.maybeOf(buttonContext)?.showSnackBar(
      const SnackBar(content: Text("Couldn't open sharing. Try again.")),
    );
  }
}
