import 'package:finnet/core/utils/json_read.dart';

/// What checking a certificate found.
enum CertificateCheck {
  /// Genuine and still valid.
  valid,

  /// Genuine, but the club has revoked it.
  revoked,

  /// No certificate has this number.
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
  final DateTime? issuedAt;

  const CertificateVerification({
    required this.result,
    this.number,
    this.attendeeName,
    this.eventName,
    this.issuer,
    this.issuedAt,
  });

  bool get isValid => result == CertificateCheck.valid;

  /// `{valid, reason: ok|revoked|not_found, number, attendee_name,
  /// event_name, org_name, issued_at}`. Valid only when the server says
  /// both `valid` and `ok`; a reason it does not know reads as not found.
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
      issuedAt: jsonDate(json['issued_at'])?.toLocal(),
    );
  }
}

/// What someone typed, scanned or pasted, as the code the server looks up;
/// null when there is nothing in it to look up.
///
/// - The QR on a certificate holds `certificate:MOA-XXXXX-XXXXX`.
/// - The number printed beside it is `CERT-XXXXX-XXXXX`.
/// - A link to the certificate's page ends in its ticket id
///   (`https://myotherapp.in/certificates/MOA-XXXXX-XXXXX`).
///
/// Ticket ids are upper case, and the server matches them exactly, so what
/// was typed is upper-cased: `cert-7k3qf-x9pwm` finds `CERT-7K3QF-X9PWM`.
String? certificateCodeFrom(String input) {
  var code = input.trim();
  if (code.isEmpty) return null;
  final link = Uri.tryParse(code);
  if (link != null &&
      (link.isScheme('https') || link.isScheme('http')) &&
      link.pathSegments.isNotEmpty) {
    code = link.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
  }
  if (code.toLowerCase().startsWith('certificate:')) {
    code = code.substring('certificate:'.length);
  }
  code = code.replaceAll(RegExp(r'\s'), '').toUpperCase();
  return code.isEmpty ? null : code;
}
