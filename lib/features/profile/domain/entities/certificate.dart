import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/core/utils/json_read.dart';

/// The certificate id (its ticket id) in a certificate's address -- the
/// website's `https://myotherapp.in/certificates/{id}`, which the server
/// sends as `certificate_url`, or an older server's
/// `/api/v1/events/certificates/{id}` -- or null for anything else.
String? certificateIdFromUrl(String? url) {
  final text = url?.trim() ?? '';
  const marker = '/certificates/';
  final at = text.lastIndexOf(marker);
  if (at < 0) return null;
  var id = text.substring(at + marker.length).split(RegExp('[?#/]')).first;
  try {
    id = Uri.decodeComponent(id).trim();
  } catch (_) {
    return null;
  }
  return id.isEmpty ? null : id;
}

/// The certificate inside the app: `/certificates/{id}`, which opens the
/// person's own as the club designed it, saved for offline.
String certificateRoute(String ticketId) =>
    '/certificates/${Uri.encodeComponent(ticketId)}';

/// A certificate the user holds for an event.
///
/// There is no certificate table: a certificate is a registration the
/// organiser issued one to (or that checked in before any were issued),
/// and the server marks those `has_certificate` and attaches
/// `certificate_url`. So this is built from the event list filtered to the
/// user's registrations ([holdsCertificate]).
class Certificate {
  /// The registration's ticket id, which is also the certificate's id --
  /// it is what the PDF and web views are keyed by.
  final String ticketId;

  final int eventId;
  final String eventName;
  final String? clubName;
  final String? clubLogoUrl;

  /// "Workshop", "Competition", and so on.
  final String? eventType;

  /// When the event happened, which is when the certificate was earned.
  final DateTime issuedOn;

  /// The event poster. The certificate itself is the server's render
  /// ([imageUrl]), kept on the phone by CertificateDocuments.
  final String? thumbnailUrl;

  const Certificate({
    required this.ticketId,
    required this.eventId,
    required this.eventName,
    required this.issuedOn,
    this.clubName,
    this.clubLogoUrl,
    this.eventType,
    this.thumbnailUrl,
  });

  /// The number printed on the certificate, `CERT-XXXXX-XXXXX`: the ticket
  /// id's, under the certificate's own prefix -- never readable as the
  /// ticket (the backend's `certificate_number`).
  String get number {
    final dash = ticketId.indexOf('-');
    return 'CERT-${dash >= 0 ? ticketId.substring(dash + 1) : ticketId}';
  }

  /// Its page on the website, which anyone with the link can open.
  String get shareUrl =>
      '${AppConfig.publicSiteUrl}/certificates/${Uri.encodeComponent(ticketId)}';

  /// Where the PDF lives. The endpoint takes no auth, so this can be opened
  /// directly; it refuses for a registration that never checked in.
  String pdfUrl(String apiBaseUrl) =>
      '$apiBaseUrl/events/certificates/$ticketId/pdf';

  /// The same certificate as a PNG, for showing on screen.
  ///
  /// Rendered from the same template by the same engine as the PDF, so the
  /// preview and the download are the same document. Showing the PDF itself
  /// meant Apple's PDF viewer chrome -- a page counter, a page frame, and
  /// the certificate shrunk inside a sheet of white.
  String imageUrl(String apiBaseUrl) =>
      '$apiBaseUrl/events/certificates/$ticketId/image';

  /// Whether the registration [json] carries a certificate the server
  /// will hand over. The server says so itself (`has_certificate`): issued
  /// by the organiser and not revoked, or checked in before any were
  /// issued -- so a speaker issued one without checking in has one, and a
  /// revoked one is gone. An older server sends only `is_attended`.
  ///
  /// Listing one the server refuses offered a render that never came, and
  /// the app's own drawing stood in for the club's design.
  static bool holdsCertificate(Map<String, dynamic> json) {
    final held = json['has_certificate'];
    if (held is bool) return held;
    return json['is_attended'] == true;
  }

  /// The title shown on the card and the detail screen.
  ///
  /// The event's own name, with "Certificate" appended only when the name
  /// does not already say so -- "Ideathon Winner Certificate Certificate"
  /// is how that goes wrong.
  String get title {
    final name = eventName.trim();
    if (name.toLowerCase().contains('certificate')) return name;
    return '$name Certificate';
  }

  static Certificate? fromEventJson(Map<String, dynamic> json) {
    final ticketId = jsonString(json['ticket_id']);
    if (ticketId == null || ticketId.isEmpty) return null;
    if (!holdsCertificate(json)) return null;

    final club = jsonObject(json['club']);
    final category = jsonObject(json['category']);

    return Certificate(
      ticketId: ticketId,
      eventId: jsonInt(json['id']) ?? 0,
      eventName: jsonString(json['name']) ?? 'Event',
      clubName: jsonString(club?['name']),
      // A club with no logo sends null, an older row a bare URL; a cast to
      // a map threw on the second and lost the whole certificate.
      clubLogoUrl: imageUrlFrom(club?['logo']),
      eventType: jsonString(category?['name']),
      issuedOn:
          DateTime.tryParse(jsonString(json['event_datetime']) ?? '')?.toLocal() ??
              DateTime.now(),
      thumbnailUrl: imageUrlFrom(json['poster']),
    );
  }
}
