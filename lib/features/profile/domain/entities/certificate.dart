import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/core/utils/json_read.dart';

/// The id at the end of a certificate's address -- the website's
/// `https://myotherapp.in/certificates/{id}`, which the server sends as
/// `certificate_url`, or an API address `/api/v1/events/certificates/{id}`
/// -- or null for anything else.
///
/// Today's server puts the certificate's public id there
/// ([isCertificatePublicId]). An older one put the ticket id, so a list
/// saved on the phone can still hold one of those.
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

/// What a certificate's public id is: 24 URL-safe characters (the
/// backend's `CERTIFICATE_PUBLIC_ID`). Its public page, its public PDF and
/// the verifier go by it. Case matters.
final _publicId = RegExp(r'^[A-Za-z0-9_-]{24}$');

/// Whether [id] is a certificate's public id, rather than a ticket id or
/// anything else.
bool isCertificatePublicId(String? id) =>
    id != null && _publicId.hasMatch(id);

/// The public id at the end of [url], or null when the id there is not
/// one (an older address, or not a certificate's at all).
String? certificatePublicIdFromUrl(String? url) {
  final id = certificateIdFromUrl(url);
  return isCertificatePublicId(id) ? id : null;
}

/// The certificate inside the app from a link to it,
/// `/certificates/{public id}`, as the website's address has it: the
/// person's own opens as the club designed it, saved for offline; anyone
/// else's is its public page.
String certificateRoute(String publicId) =>
    '/certificates/${Uri.encodeComponent(publicId)}';

/// The person's own certificate inside the app, by its ticket id:
/// `/profile/certificates/{ticket id}`. Signed in only.
String ownCertificateRoute(String ticketId) =>
    '/profile/certificates/${Uri.encodeComponent(ticketId)}';

/// Where VIEW CERTIFICATE goes for the server's `certificate_url`, or null
/// when it names no certificate.
///
/// The public route by the certificate's public id, as the server sends it
/// now. An event list saved by an older build can still hold an address
/// ending in the ticket id: that opens the person's own certificate screen
/// (signed in), never the public route.
String? certificateLocationFor(String? certificateUrl) {
  final id = certificateIdFromUrl(certificateUrl);
  if (id == null) return null;
  return isCertificatePublicId(id)
      ? certificateRoute(id)
      : ownCertificateRoute(id);
}

/// A certificate the user holds for an event.
///
/// There is no certificate table: a certificate is a registration the
/// organiser issued one to, and the server marks those `has_certificate`
/// and attaches `certificate_url` and `certificate_no`. So this is built
/// from the event list filtered to the user's registrations
/// ([holdsCertificate]).
class Certificate {
  /// The registration's ticket id. The signed-in render, PDF and style are
  /// fetched by it (the server answers only the holder), and the copies
  /// kept on the phone and the pins are filed under it. Never part of an
  /// address that is shared or opened outside the app.
  final String ticketId;

  /// The number printed on the certificate, `CERT-XXXXX-XXXXX`, as the
  /// server sends it (`certificate_no`). Null when it sent none: the app
  /// shows no number rather than make one up.
  final String? number;

  /// Its public page on the website, which anyone with the link can open,
  /// as the server sends it (`certificate_url`): by the certificate's
  /// public id. Null when there is none, and then nothing is shared.
  final String? shareUrl;

  final int eventId;
  final String eventName;
  final String? clubName;
  final String? clubLogoUrl;

  /// "Workshop", "Competition", and so on.
  final String? eventType;

  /// When the event happened, which is when the certificate was earned.
  final DateTime issuedOn;

  /// The event poster. The certificate itself is the server's render, kept
  /// on the phone by CertificateDocuments.
  final String? thumbnailUrl;

  const Certificate({
    required this.ticketId,
    required this.eventId,
    required this.eventName,
    required this.issuedOn,
    this.number,
    this.shareUrl,
    this.clubName,
    this.clubLogoUrl,
    this.eventType,
    this.thumbnailUrl,
  });

  /// The certificate's public id, from the end of [shareUrl]; null without
  /// one.
  String? get publicId => certificatePublicIdFromUrl(shareUrl);

  /// What the verifier is asked for this certificate: its printed number,
  /// else its public id. Null with neither.
  String? get verifyCode => number ?? publicId;

  /// The PDF anyone can open, by the certificate's public id: for the
  /// browser, when the phone cannot open the PDF the app fetched. Null
  /// without a public id. The ticket-id address answers only the signed-in
  /// holder, so it is never handed to the browser.
  String? publicPdfUrl(String apiBaseUrl) {
    final id = publicId;
    return id == null ? null : '$apiBaseUrl/events/certificates/$id/pdf';
  }

  /// Whether the registration [json] carries a certificate the server
  /// will hand over. The server says so itself (`has_certificate`): the
  /// organiser issued one and has not revoked it. A speaker issued one
  /// without checking in has one; someone who checked in at an event that
  /// issued nothing does not.
  ///
  /// This is the app's only answer to "is there a certificate". Checking
  /// in is attendance, not a certificate: reading `is_attended` instead
  /// promised a certificate no club had issued, and the screens offered a
  /// render that never came.
  static bool holdsCertificate(Map<String, dynamic> json) =>
      json['has_certificate'] == true;

  /// Whether the organiser issued this person a certificate and then took
  /// it back (`certificate_revoked`). Said differently from one that was
  /// never issued: there was something, and it is gone.
  static bool wasRevoked(Map<String, dynamic> json) =>
      json['certificate_revoked'] == true;

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

  /// The server's `certificate_url` when it is a certificate's public page
  /// (it ends in a public id). Null for none, and for an older address --
  /// one saved on the phone before the server changed -- which now opens
  /// for nobody but the holder.
  static String? shareUrlFrom(Map<String, dynamic> json) {
    final url = jsonString(json['certificate_url'])?.trim();
    return certificatePublicIdFromUrl(url) == null ? null : url;
  }

  /// The server's `certificate_no`, or null when it sent none (an older
  /// server, or a list saved before it sent one).
  static String? numberFrom(Map<String, dynamic> json) {
    final number = jsonString(json['certificate_no'])?.trim();
    return number == null || number.isEmpty ? null : number;
  }

  static Certificate? fromEventJson(Map<String, dynamic> json) {
    final ticketId = jsonString(json['ticket_id']);
    if (ticketId == null || ticketId.isEmpty) return null;
    if (!holdsCertificate(json)) return null;

    final club = jsonObject(json['club']);
    final category = jsonObject(json['category']);

    return Certificate(
      ticketId: ticketId,
      number: numberFrom(json),
      shareUrl: shareUrlFrom(json),
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
