import 'package:flutter/material.dart';

/// How a club's certificate is styled.
///
/// Mirrors GET /events/certificates/{ticket_id}/style, which exists -- in
/// the server's own words -- "so the event website can render a styled
/// preview". The app renders one the same way: there is no image of a
/// certificate anywhere, only a PDF generated on demand, so a preview has
/// to be drawn rather than fetched.
class CertificateStyle {
  final Color background;
  final Color accent;
  final Color text;
  final Color secondaryText;
  final Color border;
  final String title;
  final bool landscape;
  final bool showCertificateId;
  final String? logoUrl;
  final String? backgroundImageUrl;

  const CertificateStyle({
    required this.background,
    required this.accent,
    required this.text,
    required this.secondaryText,
    required this.border,
    required this.title,
    required this.landscape,
    required this.showCertificateId,
    this.logoUrl,
    this.backgroundImageUrl,
  });

  /// What to show before the style arrives, or if it cannot be fetched.
  /// Deliberately plain rather than branded -- guessing a club's colours
  /// would look like a rendering bug once the real ones loaded.
  static const fallback = CertificateStyle(
    background: Color(0xFF121212),
    accent: Color(0xFF1DB9A0),
    text: Colors.white,
    secondaryText: Color(0xFFAAAAAA),
    border: Color(0xFF1DB9A0),
    title: 'Certificate of Participation',
    landscape: true,
    showCertificateId: true,
  );

  factory CertificateStyle.fromJson(Map<String, dynamic> json) {
    return CertificateStyle(
      background: _color(json['bg_color'], fallback.background),
      accent: _color(json['accent_color'], fallback.accent),
      text: _color(json['text_color'], fallback.text),
      secondaryText:
          _color(json['secondary_text_color'], fallback.secondaryText),
      border: _color(json['border_color'], fallback.border),
      title: (json['certificate_title'] as String?)?.trim().isNotEmpty == true
          ? json['certificate_title'] as String
          : fallback.title,
      landscape: (json['orientation'] as String?) != 'portrait',
      showCertificateId: json['show_certificate_id'] as bool? ?? true,
      logoUrl: json['logo_url'] as String?,
      backgroundImageUrl: json['background_image_url'] as String?,
    );
  }

  /// Parse "#rrggbb" or "#aarrggbb". A club can put anything in this field,
  /// and a malformed colour must not take the screen down.
  static Color _color(dynamic value, Color fallback) {
    if (value is! String) return fallback;
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'ff$hex';
    if (hex.length != 8) return fallback;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}
