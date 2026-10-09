import 'package:finnet/features/profile/domain/entities/certificate_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The detail panel used to show the event's poster, falling back to an icon
/// when there was none -- which is most events, so it showed a logo and
/// nothing of the certificate. There is no image to fetch: certificates are
/// generated as PDFs on request. The preview is drawn from this config, the
/// same one the event website renders from.
void main() {
  group('CertificateStyle.fromJson', () {
    test('reads the real production payload', () {
      final style = CertificateStyle.fromJson(const {
        'accent_color': '#1db9a0',
        'bg_color': '#121212',
        'text_color': '#ffffff',
        'secondary_text_color': '#aaaaaa',
        'border_color': '#1db9a0',
        'certificate_title': 'Certificate of Participation',
        'orientation': 'landscape',
        'show_certificate_id': true,
      });

      expect(style.accent, const Color(0xFF1DB9A0));
      expect(style.background, const Color(0xFF121212));
      expect(style.title, 'Certificate of Participation');
      expect(style.landscape, isTrue);
      expect(style.showCertificateId, isTrue);
    });

    test('portrait is the only thing that is not landscape', () {
      expect(
        CertificateStyle.fromJson(const {'orientation': 'portrait'}).landscape,
        isFalse,
      );
      expect(
        CertificateStyle.fromJson(const {}).landscape,
        isTrue,
      );
    });

    test('a malformed colour falls back instead of throwing', () {
      // A club can put anything in this field.
      final style = CertificateStyle.fromJson(const {
        'accent_color': 'not-a-colour',
        'bg_color': '#xyz',
        'text_color': 42,
      });

      expect(style.accent, CertificateStyle.fallback.accent);
      expect(style.background, CertificateStyle.fallback.background);
      expect(style.text, CertificateStyle.fallback.text);
    });

    test('a colour without a hash still parses', () {
      expect(
        CertificateStyle.fromJson(const {'accent_color': '1db9a0'}).accent,
        const Color(0xFF1DB9A0),
      );
    });

    test('an eight-digit colour keeps its alpha', () {
      expect(
        CertificateStyle.fromJson(const {'accent_color': '#801db9a0'}).accent,
        const Color(0x801DB9A0),
      );
    });

    test('an empty title falls back rather than rendering blank', () {
      expect(
        CertificateStyle.fromJson(const {'certificate_title': '   '}).title,
        CertificateStyle.fallback.title,
      );
    });

    test('an empty payload yields the fallback throughout', () {
      final style = CertificateStyle.fromJson(const {});

      expect(style.title, CertificateStyle.fallback.title);
      expect(style.accent, CertificateStyle.fallback.accent);
      expect(style.showCertificateId, isTrue);
    });
  });
}
