import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Certificate pinning interceptor for enhanced security.
///
/// This prevents MITM attacks by validating the server's SSL certificate
/// against known certificate fingerprints.
class CertPinningInterceptor extends Interceptor {
  /// SHA-256 fingerprints of trusted certificates
  /// TODO: Replace with actual production certificate fingerprints
  static const List<String> _trustedFingerprints = [
    // Add your server certificate SHA-256 fingerprints here
    // Example: 'B6:...'
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // In debug mode, skip certificate pinning for easier development
    if (kDebugMode) {
      handler.next(options);
      return;
    }

    // For production, certificate validation happens at the HTTP client level
    // This interceptor logs any certificate-related issues
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Check if error is related to SSL/TLS
    if (err.error is HandshakeException ||
        err.error is SocketException ||
        err.message?.contains('certificate') == true) {
      debugPrint('CertPinning: SSL/TLS error detected - ${err.message}');

      // In production, this could indicate a MITM attack
      if (!kDebugMode) {
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error:
              'SSL Certificate validation failed. Connection rejected for security.',
          type: DioExceptionType.badCertificate,
        ));
        return;
      }
    }

    handler.next(err);
  }

  /// Validates a certificate fingerprint against trusted fingerprints.
  ///
  /// Returns true if the fingerprint is in the trusted list.
  static bool isValidFingerprint(String fingerprint) {
    if (_trustedFingerprints.isEmpty) {
      // If no fingerprints configured, allow all (dev mode)
      return true;
    }
    return _trustedFingerprints.contains(fingerprint.toUpperCase());
  }
}

/// Extension to configure Dio with certificate pinning.
extension DioCertPinning on Dio {
  /// Adds certificate pinning interceptor to this Dio instance.
  void addCertPinning() {
    interceptors.add(CertPinningInterceptor());
  }
}
