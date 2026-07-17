import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finnet/core/network/interceptors/cert_pinning_interceptor.dart';

void main() {
  group('configureCertPinning', () {
    test(
      'fails open (does not install a badCertificateCallback) when no fingerprints are configured',
      () {
        final dio = Dio()..httpClientAdapter = IOHttpClientAdapter();

        // Must not throw, and must leave the adapter's factory unset — an
        // empty trusted-fingerprint list should never block all traffic.
        expect(() => configureCertPinning(dio), returnsNormally);

        final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
        expect(adapter.createHttpClient, isNull);
      },
    );

    test('is a no-op for non-IOHttpClientAdapter instances', () {
      final dio = Dio();

      expect(() => configureCertPinning(dio), returnsNormally);
    });
  });
}
