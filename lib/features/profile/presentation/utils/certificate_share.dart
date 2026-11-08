import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:share_plus/share_plus.dart';

/// Whether [certificate] can be shared: only with the page the server
/// gave it (`certificate_url`). Without one there is no share action.
bool canShareCertificate(Certificate certificate) =>
    certificate.shareUrl != null;

/// What sharing a certificate says beside the file: its page on the
/// website, and the number anyone can check it by, both as the server sent
/// them. Null without the page ([canShareCertificate]); the number line is
/// left out when the server sent no number.
String? certificateShareText(Certificate certificate) {
  final url = certificate.shareUrl;
  if (url == null) return null;
  final club = certificate.clubName?.trim() ?? '';
  final event = certificate.eventName.trim();
  final what = club.isEmpty ? event : '$event, from $club';
  final number = certificate.number;
  return [
    'My certificate for $what: $url',
    if (number != null) 'Certificate number: $number',
  ].join('\n');
}

/// Hands the certificate's PDF ([pdfPath]) and [text] -- or the text
/// alone, with no PDF -- to the phone's share sheet. A provider so a test
/// can see what would have been shared.
typedef CertificateSharer = Future<void> Function(
  String text, {
  String? subject,
  Rect? origin,
  String? pdfPath,
});

final certificateSharerProvider = Provider<CertificateSharer>(
  (ref) => (text, {subject, origin, pdfPath}) async {
    if (pdfPath == null) {
      await Share.share(text, subject: subject, sharePositionOrigin: origin);
      return;
    }
    await Share.shareXFiles(
      [XFile(pdfPath, mimeType: 'application/pdf')],
      text: text,
      subject: subject,
      sharePositionOrigin: origin,
    );
  },
);

/// Share [certificate] from the button at [buttonContext] (the sheet points
/// at it on an iPad). Nothing happens for one without its page
/// ([canShareCertificate]); the screens offer no button for it.
///
/// The certificate itself goes: the PDF the club's email attaches, kept on
/// the phone (so it shares offline once saved), with the link and number
/// beside it. The link alone sent people to the website's page, which draws
/// one stand-in design for every club. Without the PDF -- never saved and
/// no network -- the link alone, as before.
Future<void> shareCertificate(
  BuildContext buttonContext,
  WidgetRef ref,
  Certificate certificate,
) async {
  final text = certificateShareText(certificate);
  if (text == null) return;
  final box = buttonContext.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  String? pdfPath;
  try {
    pdfPath = (await ref
            .read(certificateDocumentsProvider)
            .pdf(certificate.ticketId))
        .file
        .path;
  } catch (e) {
    debugPrint('Certificate PDF unavailable, sharing the link: $e');
  }
  try {
    await ref.read(certificateSharerProvider)(
      text,
      subject: certificate.title,
      origin: origin,
      pdfPath: pdfPath,
    );
  } catch (e) {
    debugPrint('Certificate share failed: $e');
    if (!buttonContext.mounted) return;
    ScaffoldMessenger.maybeOf(buttonContext)?.showSnackBar(
      const SnackBar(content: Text("Couldn't open sharing. Try again.")),
    );
  }
}
