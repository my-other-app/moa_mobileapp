import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:share_plus/share_plus.dart';

/// What sharing a certificate sends: its page on the website, which anyone
/// with the link can open, and the number anyone can check it by.
String certificateShareText(Certificate certificate) {
  final club = certificate.clubName?.trim() ?? '';
  final event = certificate.eventName.trim();
  final what = club.isEmpty ? event : '$event, from $club';
  return 'My certificate for $what: ${certificate.shareUrl}\n'
      'Certificate number: ${certificate.number}';
}

/// Hands text to the phone's share sheet. A provider so a test can see what
/// would have been shared.
typedef CertificateSharer = Future<void> Function(
  String text, {
  String? subject,
  Rect? origin,
});

final certificateSharerProvider = Provider<CertificateSharer>(
  (ref) => (text, {subject, origin}) =>
      Share.share(text, subject: subject, sharePositionOrigin: origin),
);

/// Share [certificate] from the button at [buttonContext] (the sheet points
/// at it on an iPad).
Future<void> shareCertificate(
  BuildContext buttonContext,
  WidgetRef ref,
  Certificate certificate,
) async {
  final box = buttonContext.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    await ref.read(certificateSharerProvider)(
      certificateShareText(certificate),
      subject: certificate.title,
      origin: origin,
    );
  } catch (e) {
    debugPrint('Certificate share failed: $e');
    if (!buttonContext.mounted) return;
    ScaffoldMessenger.maybeOf(buttonContext)?.showSnackBar(
      const SnackBar(content: Text("Couldn't open sharing. Try again.")),
    );
  }
}
