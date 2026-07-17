import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:finnet/core/services/analytics_service.dart';

/// SHA-256 fingerprints (hex, uppercase) of the trusted server's leaf TLS
/// certificate(s). Pinned at the leaf (not the public key/SPKI) for
/// simplicity — this means the pin must be updated on every certificate
/// renewal, not just on a key-pair change, but avoids needing an ASN.1
/// parser to extract just the SubjectPublicKeyInfo.
///
/// To obtain the value once production TLS is confirmed live:
///   openssl s_client -connect api.finnet.app:443 -servername api.finnet.app `</dev/null` 2>/dev/null \
///     | openssl x509 -noout -fingerprint -sha256
///
/// Include both the current and next certificate's fingerprint during a
/// planned rotation window to avoid an outage.
const List<String> _trustedFingerprints = [
  // Add production certificate SHA-256 fingerprints here, e.g.:
  // 'B6:2F:...',
];

bool _hasWarnedMissingPins = false;

/// Wires certificate pinning into [dio] at the TLS handshake layer via a
/// `badCertificateCallback`, so an untrusted certificate is rejected before
/// any request/response is exchanged (not just reacted to afterward).
///
/// If [_trustedFingerprints] is empty, this **fails open** (does not
/// enforce pinning) rather than failing closed — an empty list blocking all
/// production traffic because someone forgot to fill in a constant would be
/// worse than the absence of pinning. A loud one-time warning is logged
/// instead so this doesn't go unnoticed.
void configureCertPinning(Dio dio) {
  if (_trustedFingerprints.isEmpty) {
    if (!_hasWarnedMissingPins) {
      _hasWarnedMissingPins = true;
      debugPrint(
        'CertPinning: no trusted fingerprints configured for a production '
        'build — connections are NOT pinned. Fill in _trustedFingerprints '
        'in cert_pinning_interceptor.dart before shipping.',
      );
      // Best-effort only: a failure to log this warning (e.g. Firebase not
      // yet initialized) must not itself break the fail-open path below —
      // guard both the synchronous call and the returned future.
      try {
        AnalyticsService.instance
            .logError(
              'cert_pinning_not_configured',
              parameters: const {'severity': 'high'},
            )
            .catchError(
              (e) => debugPrint('CertPinning: failed to report missing-pins warning: $e'),
            );
      } catch (e) {
        debugPrint('CertPinning: failed to report missing-pins warning: $e');
      }
    }
    return;
  }

  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        final fingerprint = _sha256Fingerprint(cert);
        final trusted = _trustedFingerprints.contains(fingerprint);
        if (!trusted) {
          debugPrint(
            'CertPinning: rejected untrusted certificate for $host:$port ($fingerprint)',
          );
        }
        return trusted;
      };
      return client;
    };
  }
}

String _sha256Fingerprint(X509Certificate cert) {
  final digest = sha256.convert(cert.der);
  return digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
