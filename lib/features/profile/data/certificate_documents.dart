import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';

/// Each certificate as the club designed it -- the server's render, as a
/// PNG, and the PDF the club's email attaches -- kept on the phone
/// ([DocumentCache]: the app's private files, deleted at sign-out).
///
/// Kept under the certificate's id (its ticket id), never its address: the
/// render's address is the same for everyone who asks, and a kept copy is
/// checked against the server with its ETag, so a redesign, a corrected
/// name or a revocation reaches the phone the next time it is online.
///
/// The certificate screen used to fetch the render through the picture
/// cache, which deletes what is not looked at for a month and shares its
/// room with everyone's profile pictures; and the event page opened the
/// website's certificate page, which keeps nothing and draws its own
/// stand-in rather than the club's design. Now the kept render is shown at
/// once, and offline.
class CertificateDocuments {
  CertificateDocuments({
    DocumentCache? cache,
    Duration? keepFor,
    Duration? keepIncompleteFor,
  })  : _cache = cache,
        keepFor = keepFor ?? const Duration(hours: 12),
        keepIncompleteFor = keepIncompleteFor ?? const Duration(hours: 1);

  static CertificateDocuments? _instance;

  /// The app's one, over [DocumentCache.instance].
  static CertificateDocuments get instance =>
      _instance ??= CertificateDocuments();

  @visibleForTesting
  static set instance(CertificateDocuments? documents) =>
      _instance = documents;

  final DocumentCache? _cache;

  /// How long a complete kept copy is good for before [prefetch] asks the
  /// server again. Opening the certificate always asks.
  final Duration keepFor;

  /// The same for one that came without an ETag (a render missing one of
  /// its images): shorter, so the whole one replaces it soon.
  final Duration keepIncompleteFor;

  DocumentCache get _documents => _cache ?? DocumentCache.instance;

  /// Where certificate [ticketId]'s render is kept.
  static String imageNameFor(String ticketId) =>
      'certificate_${DocumentCache.safeName(ticketId)}.png';

  /// Where its PDF is kept: the name the download has always used, so a
  /// PDF kept by an older build is still found.
  static String pdfNameFor(String ticketId) =>
      'certificate_${DocumentCache.safeName(ticketId)}.pdf';

  static String imagePathFor(String ticketId) =>
      '/events/certificates/$ticketId/image';

  static String pdfPathFor(String ticketId) =>
      '/events/certificates/$ticketId/pdf';

  /// The kept render of certificate [ticketId], or null. Reads the disk
  /// only.
  Future<Uint8List?> savedImage(String ticketId) async {
    final kept = await _documents.kept(imageNameFor(ticketId));
    if (kept == null) return null;
    try {
      return await kept.file.readAsBytes();
    } catch (e) {
      debugPrint('CertificateDocuments: could not read $ticketId: $e');
      return null;
    }
  }

  /// Ask the server for the render -- with the kept copy's ETag, so an
  /// unchanged one is a 304 -- and keep it. With no answer, the kept copy
  /// marked not current; with none kept, the error.
  Future<({Uint8List bytes, bool current})> fetchImage(String ticketId) async {
    final document = await _documents.fetch(
      imagePathFor(ticketId),
      name: imageNameFor(ticketId),
      extra: {RetryInterceptor.noRetryKey: true},
    );
    return (bytes: await document.file.readAsBytes(), current: document.current);
  }

  /// The PDF, kept or fetched: what Download opens and Share sends.
  Future<SavedDocument> pdf(String ticketId) => _documents.fetch(
        pdfPathFor(ticketId),
        name: pdfNameFor(ticketId),
      );

  /// Keep the PDF too, unless a fresh copy is already kept; quietly, for
  /// a Download or a Share later with no network.
  Future<void> keepPdf(String ticketId, {DateTime? now}) async {
    try {
      if (await _fresh(pdfNameFor(ticketId), now ?? DateTime.now())) return;
      await _documents.fetch(
        pdfPathFor(ticketId),
        name: pdfNameFor(ticketId),
        extra: {RetryInterceptor.noRetryKey: true},
      );
    } catch (e) {
      debugPrint('CertificateDocuments: could not keep the PDF $ticketId: $e');
    }
  }

  /// Delete what is kept of certificate [ticketId]: the server no longer
  /// hands it over (revoked, or not this person's).
  Future<void> forget(String ticketId) async {
    await _documents.remove(imageNameFor(ticketId));
    await _documents.remove(pdfNameFor(ticketId));
  }

  /// Whether [error] is the server refusing the certificate, rather than
  /// failing to answer.
  static bool isRefusal(Object error) => refusalIn(error) != null;

  /// Why the server refused the certificate, or null when it did not
  /// refuse (it answered, or could not be reached).
  ///
  /// The reason is read from the error envelope's `error_code`, never from
  /// its prose: `CERTIFICATE_NOT_ISSUED` where the organiser has issued
  /// nobody one, `CERTIFICATE_REVOKED` where this one was taken back. A
  /// refusal with no code -- an older server, or a certificate that is not
  /// this person's -- is [CertificateRefusal.gone].
  static CertificateRefusal? refusalIn(Object error) {
    final response = error is DioException ? error.response : null;
    final status = response?.statusCode;
    if (status != 403 && status != 404 && status != 410) return null;
    switch (_errorCodeIn(response?.data)) {
      case 'CERTIFICATE_NOT_ISSUED':
        return CertificateRefusal.notIssued;
      case 'CERTIFICATE_REVOKED':
        return CertificateRefusal.revoked;
      default:
        return CertificateRefusal.gone;
    }
  }

  /// The `error_code` in an error body. A render is asked for as bytes, so
  /// a refusal arrives as the envelope's bytes rather than as a map.
  static String? _errorCodeIn(Object? body) {
    Object? decoded = body;
    if (decoded is List<int> || decoded is String) {
      try {
        decoded = jsonDecode(
            decoded is String ? decoded : utf8.decode(decoded as List<int>));
      } catch (_) {
        return null;
      }
    }
    if (decoded is! Map) return null;
    final code = decoded['error_code'];
    return code is String && code.trim().isNotEmpty ? code.trim() : null;
  }

  Future<bool> _fresh(String name, DateTime now) async {
    final kept = await _documents.kept(name);
    return kept != null &&
        now.difference(kept.savedAt) <
            (kept.isFinal ? keepFor : keepIncompleteFor);
  }

  Future<void>? _running;

  /// Keep every listed certificate's render and PDF ready: one missing, or
  /// older than [keepFor] ([keepIncompleteFor] when incomplete), is
  /// fetched. One at a time, so the server -- which renders each one -- is
  /// not asked for them all at once; a second call waits for the first.
  /// [onKept] hears each render that was saved. Failures are logged and
  /// skipped; a refused one is forgotten.
  Future<void> prefetch(
    List<Certificate> certificates, {
    DateTime? now,
    void Function(String ticketId)? onKept,
  }) {
    final previous = _running ?? Future<void>.value();
    final next = previous.then((_) => _prefetch(certificates, now, onKept));
    _running = next.whenComplete(() {
      if (identical(_running, next)) _running = null;
    });
    return next;
  }

  Future<void> _prefetch(
    List<Certificate> certificates,
    DateTime? now,
    void Function(String ticketId)? onKept,
  ) async {
    for (final certificate in certificates) {
      final id = certificate.ticketId;
      final at = now ?? DateTime.now();
      try {
        if (!await _fresh(imageNameFor(id), at)) {
          await fetchImage(id);
          onKept?.call(id);
        }
        await keepPdf(id, now: at);
      } catch (e) {
        if (isRefusal(e)) await forget(id);
        debugPrint('CertificateDocuments: could not keep $id: $e');
      }
    }
  }
}

/// Why the server will not hand over a certificate.
enum CertificateRefusal {
  /// The organiser has issued no certificate for this event, or none to
  /// this person: there is nothing yet, and there may never be.
  notIssued,

  /// One was issued and the organiser took it back.
  revoked,

  /// Refused for some other reason -- it is not this person's, or the
  /// server is older than the codes.
  gone,
}

/// The app's [CertificateDocuments]; overridden in tests.
final certificateDocumentsProvider =
    Provider<CertificateDocuments>((ref) => CertificateDocuments.instance);
