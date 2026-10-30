import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/shared/widgets/rendered_document_image.dart';

/// The certificate as the club designed it: the server's render -- the
/// same document the club's email attaches -- kept on the phone under the
/// certificate's id.
///
/// The kept copy is shown at once, and offline, then checked with the
/// server (a 304 when unchanged). The app's own drawing ([fallback]) is
/// shown only when the club's render cannot be had at all -- never fetched
/// and no network, or the server failing -- and says that it is a preview.
/// A certificate the server refuses (revoked) shows neither.
class CertificateRender extends ConsumerStatefulWidget {
  const CertificateRender({
    super.key,
    required this.certificate,
    required this.fallback,
  });

  final Certificate certificate;

  /// The app's drawing of the certificate, for when the club's render
  /// cannot be had.
  final Widget fallback;

  static const loadingKey = ValueKey('certificate-loading');
  static const refreshingKey = ValueKey('certificate-refreshing');
  static const offlineNoticeKey = ValueKey('certificate-offline-notice');
  static const offlineNotice = 'Offline — showing your saved certificate';
  static const fallbackNoticeKey = ValueKey('certificate-fallback-notice');
  static const offlinePreviewNotice =
      "A preview. The club's certificate shows here once you're online.";
  static const failedPreviewNotice =
      "A preview. The club's certificate couldn't be loaded just now.";
  static const refusedKey = ValueKey('certificate-refused');
  static const refusedMessage = 'This certificate is no longer available';

  /// Nothing was ever issued for this event, so nothing is on its way
  /// unless the organiser sends it.
  static const notIssuedMessage =
      'Your certificate will appear here once the organiser issues it';

  /// One was issued and taken back -- which is not the same as never
  /// having had one, and must not read as if it were still coming.
  static const revokedMessage = 'The organiser has withdrawn this certificate';

  /// What to say for each way the server can refuse it
  /// (CertificateDocuments.refusalIn, from the 403's `error_code`).
  static String messageFor(CertificateRefusal refusal) {
    switch (refusal) {
      case CertificateRefusal.notIssued:
        return notIssuedMessage;
      case CertificateRefusal.revoked:
        return revokedMessage;
      case CertificateRefusal.gone:
        return refusedMessage;
    }
  }

  @override
  ConsumerState<CertificateRender> createState() => _CertificateRenderState();
}

class _CertificateRenderState extends ConsumerState<CertificateRender> {
  /// The club's render, kept or fresh; null until one is there.
  MemoryImage? _image;

  /// Asking the server again over the kept render.
  bool _refreshing = false;

  /// No answer from the server: the kept render, or the drawn preview.
  bool _offline = false;

  /// No render to show: the drawn preview, with a note.
  bool _failed = false;

  /// Why the server refused it (never issued, revoked, or not this
  /// person's); null while it has not refused.
  CertificateRefusal? _refusal;

  String get _id => widget.certificate.ticketId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final documents = ref.read(certificateDocumentsProvider);
    final saved = await documents.savedImage(_id);
    if (!mounted) return;
    final offline = ref.read(networkStatusProvider).isOffline;
    setState(() {
      if (saved != null) _image = MemoryImage(saved);
      _offline = offline;
      _failed = offline && saved == null;
      _refreshing = !offline && saved != null;
    });
    if (offline) return;
    try {
      final fresh = await documents.fetchImage(_id);
      if (!mounted) return;
      setState(() {
        _image = MemoryImage(fresh.bytes);
        _offline = !fresh.current;
        _refreshing = false;
        _failed = false;
      });
      // The list's thumbnail is the same file, now saved.
      ref.invalidate(keptCertificateImageProvider(_id));
      // And the PDF, so Download and Share work with no network later.
      unawaited(documents.keepPdf(_id));
    } catch (e) {
      debugPrint('Certificate render unavailable: $e');
      final refused = CertificateDocuments.refusalIn(e);
      if (refused != null) {
        await documents.forget(_id);
        ref.invalidate(keptCertificateImageProvider(_id));
      }
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _refusal = refused;
        if (refused != null) _image = null;
        _failed = _image == null;
        _offline = e is DioException && DocumentCache.noAnswer(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final refusal = _refusal;
    if (refusal != null) return _Refused(refusal);
    final image = _image;
    if (image != null) {
      final rendered = RenderedDocumentImage(
        url: widget.certificate.imageUrl(Env.apiBaseUrl),
        image: image,
        placeholder: const _Loading(),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_refreshing)
            Stack(
              children: [
                rendered,
                const Positioned(top: 8, right: 8, child: _Refreshing()),
              ],
            )
          else
            rendered,
          if (_offline)
            const _Note(
              key: CertificateRender.offlineNoticeKey,
              icon: Icons.cloud_off,
              text: CertificateRender.offlineNotice,
            ),
        ],
      );
    }
    if (!_failed) return const _Loading();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.fallback,
        _Note(
          key: CertificateRender.fallbackNoticeKey,
          icon: _offline ? Icons.cloud_off : Icons.info_outline,
          text: _offline
              ? CertificateRender.offlinePreviewNotice
              : CertificateRender.failedPreviewNotice,
        ),
      ],
    );
  }
}

/// While the render loads: a panel the shape of a certificate, not the
/// app's drawing of one, which looks nothing like what the club designed.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: CertificateRender.loadingKey,
      aspectRatio: 800 / 519,
      child: ColoredBox(
        color: Colors.white.withAlpha(150),
        child: const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}

class _Refreshing extends StatelessWidget {
  const _Refreshing();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: CertificateRender.refreshingKey,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(110),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
    );
  }
}

/// The server will not hand the certificate over, and says why: one still
/// to be issued waits on the organiser, one withdrawn is gone. Nothing
/// that was never issued is drawn as a preview -- there is no certificate
/// to preview.
class _Refused extends StatelessWidget {
  const _Refused(this.refusal);

  final CertificateRefusal refusal;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: CertificateRender.refusedKey,
      aspectRatio: 800 / 519,
      child: ColoredBox(
        color: Colors.white.withAlpha(170),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  refusal == CertificateRefusal.notIssued
                      ? Icons.hourglass_empty
                      : Icons.block,
                  size: 32,
                  color: const Color(0xFF1E1E1E),
                ),
                const SizedBox(height: 10),
                Text(
                  CertificateRender.messageFor(refusal),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF1E1E1E)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1E1E1E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
            ),
          ),
        ],
      ),
    );
  }
}
