import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';

/// What checking a certificate found.
enum CertificateCheck {
  /// Genuine and still valid.
  valid,

  /// Genuine, but the club has revoked it.
  revoked,

  /// No certificate has this number or link (`not_found`).
  notFound,
}

/// The answer of `GET /verify/certificates/{code}`: genuine or not, valid or
/// revoked, whose, for what, from whom and when -- and nothing more.
class CertificateVerification {
  final CertificateCheck result;

  /// The certificate's number, `CERT-XXXXX-XXXXX`.
  final String? number;
  final String? attendeeName;
  final String? eventName;

  /// Who issued it: the club that ran the event.
  final String? issuer;

  /// The club's handle, for its page (`org_slug`).
  final String? issuerSlug;
  final DateTime? issuedAt;

  const CertificateVerification({
    required this.result,
    this.number,
    this.attendeeName,
    this.eventName,
    this.issuer,
    this.issuerSlug,
    this.issuedAt,
  });

  bool get isValid => result == CertificateCheck.valid;

  /// `{valid, reason: ok|revoked|not_found, number, attendee_name,
  /// event_name, org_name, org_slug, issued_at}`. Valid only when the
  /// server says both `valid` and `ok`; a reason it does not know reads as
  /// not found. A revoked one names the event and the club, not the
  /// person.
  factory CertificateVerification.fromJson(Map<String, dynamic> json) {
    final reason = jsonString(json['reason']);
    final result = json['valid'] == true && (reason == null || reason == 'ok')
        ? CertificateCheck.valid
        : reason == 'revoked'
            ? CertificateCheck.revoked
            : CertificateCheck.notFound;
    return CertificateVerification(
      result: result,
      number: jsonString(json['number']),
      attendeeName: jsonString(json['attendee_name']),
      eventName: jsonString(json['event_name']),
      issuer: jsonString(json['org_name']),
      issuerSlug: jsonString(json['org_slug']),
      issuedAt: jsonDate(json['issued_at'])?.toLocal(),
    );
  }
}

/// The number printed on a certificate, `CERT-XXXXX-XXXXX`, upper case.
final _number = RegExp(r'^CERT-[A-Z0-9]{5}-[A-Z0-9]{5}$');

/// Whether [code] (as [certificateCodeFrom] gives it) is a printed number,
/// rather than a certificate's public id.
bool isCertificateNumber(String code) => _number.hasMatch(code);

/// What someone typed, scanned or pasted, as the code the server looks up:
/// the certificate's public id or its printed number. Null when it holds
/// neither, and then nothing is sent.
///
/// - A link to the certificate's page ends in its public id,
///   `https://myotherapp.in/certificates/{24 characters}`. The id is sent
///   exactly as it is: its case matters.
/// - The number printed on it is `CERT-XXXXX-XXXXX`; typed in any case,
///   with or without its dashes or spaces, it is sent upper case.
/// - Its QR code holds a link to the public verifier with that number,
///   `https://myotherapp.in/verify/CERT-XXXXX-XXXXX`.
///
/// Either is found inside whatever else was pasted with it: the message a
/// holder shares has the link and the number. A ticket id is never a
/// certificate's code, so one (or the `certificate:MOA-...` an older
/// certificate's QR held) is not looked up.
String? certificateCodeFrom(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  for (final part in text.split(RegExp(r'[^A-Za-z0-9_-]+'))) {
    if (isCertificatePublicId(part)) return part;
  }
  final number = _typedNumber.firstMatch(text);
  if (number == null) return null;
  return 'CERT-${number[1]!.toUpperCase()}-${number[2]!.toUpperCase()}';
}

/// A printed number as it may be typed: any case, its dashes or spaces
/// optional, on its own rather than inside a longer word.
final _typedNumber = RegExp(
  r'(?<![A-Za-z0-9])CERT[-\s]?([A-Za-z0-9]{5})[-\s]?([A-Za-z0-9]{5})(?![A-Za-z0-9])',
  caseSensitive: false,
);
