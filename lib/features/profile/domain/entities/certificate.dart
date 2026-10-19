import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/core/utils/json_read.dart';

/// A certificate the user has earned by attending an event.
///
/// There is no certificate table: a certificate exists when a registration
/// has `is_attended`, and the server attaches `certificate_url` to those.
/// So this is built from the event list filtered to the user's attended
/// registrations.
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

  /// The event poster, used as the card's thumbnail. The certificate itself
  /// renders server-side as a PDF, so there is no image of it to show.
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
    // No ticket, or never checked in, means no certificate to show. The
    // server refuses the PDF for those, so listing them would offer a
    // download that cannot succeed.
    if (ticketId == null || ticketId.isEmpty) return null;
    if (json['is_attended'] != true) return null;

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
