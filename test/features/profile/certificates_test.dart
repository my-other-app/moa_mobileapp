import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Certificate cert({
  String ticketId = 't1',
  String name = 'Blender Workshop',
  String? club = 'IEDC CET',
  String? type = 'Workshop',
  DateTime? on,
}) =>
    Certificate(
      ticketId: ticketId,
      eventId: 1,
      eventName: name,
      clubName: club,
      eventType: type,
      issuedOn: on ?? DateTime(2024, 1, 29),
    );

void main() {
  group('building a certificate from an event', () {
    test('a registration the organiser issued one to becomes one', () {
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Oasis Hackathon',
        'ticket_id': 'MOA-4KD9W-22XQZ',
        'is_attended': true,
        'has_certificate': true,
        'event_datetime': '2024-01-04T10:00:00+00:00',
        'club': {'name': 'Tinkerhub', 'logo': {'thumbnail': 'logo.png'}},
        'category': {'name': 'Hackathon'},
      });

      expect(result, isNotNull);
      expect(result!.ticketId, 'MOA-4KD9W-22XQZ');
      expect(result.clubName, 'Tinkerhub');
      expect(result.eventType, 'Hackathon');
    });

    test('a club with no logo, or a bare URL for one, still makes one', () {
      Map<String, dynamic> event(Object? logo) => {
            'id': 7,
            'name': 'Oasis Hackathon',
            'ticket_id': 'MOA-1',
            'is_attended': true,
            'has_certificate': true,
            'club': {'name': 'Tinkerhub', 'logo': logo},
            'poster': 'https://img/poster.png',
          };

      final none = Certificate.fromEventJson(event(null));
      final bare = Certificate.fromEventJson(event('https://img/logo.png'));

      expect(none, isNotNull);
      expect(none!.clubLogoUrl, isNull);
      expect(bare!.clubLogoUrl, 'https://img/logo.png');
      expect(bare.thumbnailUrl, 'https://img/poster.png');
    });

    test('a registration without attendance does not', () {
      // The server refuses the PDF for these, so listing one would offer a
      // download that cannot succeed.
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Oasis Hackathon',
        'ticket_id': 'MOA-1',
        'is_attended': false,
        'event_datetime': '2024-01-04T10:00:00+00:00',
      });

      expect(result, isNull);
    });

    test('a check-in at an event that issued nothing does not', () {
      // The whole of the bug: being at the event is not a certificate.
      // The club issued none, so there is nothing to list, nothing to
      // render and nothing to download.
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Oasis Hackathon',
        'ticket_id': 'MOA-1',
        'is_attended': true,
        'has_certificate': false,
        'event_datetime': '2024-01-04T10:00:00+00:00',
      });

      expect(result, isNull);
    });

    test('one the organiser issued without a check-in becomes one', () {
      // A speaker issued a certificate from the clubs dashboard: the email
      // went out, the PDF and the render are served, and the app listed
      // nothing because it asked only whether they checked in.
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Oasis Hackathon',
        'ticket_id': 'MOA-1',
        'is_attended': false,
        'has_certificate': true,
        'event_datetime': '2024-01-04T10:00:00+00:00',
      });
      expect(result, isNotNull);
    });

    test('a revoked one does not, though they checked in', () {
      // Listed, its render was refused and the app's own drawing stood in.
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Oasis Hackathon',
        'ticket_id': 'MOA-1',
        'is_attended': true,
        'has_certificate': false,
        'certificate_revoked': true,
        'event_datetime': '2024-01-04T10:00:00+00:00',
      });
      expect(result, isNull);
    });

    test('an event with no ticket does not', () {
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Some Event',
        'is_attended': true,
        'event_datetime': '2024-01-04T10:00:00+00:00',
      });

      expect(result, isNull);
    });
  });

  group('title', () {
    test('appends Certificate to the event name', () {
      expect(cert(name: 'Blender Workshop').title,
          'Blender Workshop Certificate');
    });

    test('does not append it twice', () {
      // "Ideathon Winner Certificate Certificate" is how that goes wrong.
      expect(cert(name: 'Ideathon Winner Certificate').title,
          'Ideathon Winner Certificate');
    });
  });

  group("the number and the page come from the server", () {
    const publicId = 'q7Lk2Vb9_xR4mT0aZ-c8NwPe';
    Map<String, dynamic> row({Object? url, Object? number}) => {
          'id': 7,
          'name': 'Oasis Hackathon',
          'ticket_id': 'MOA-4KD9W-22XQZ',
          'has_certificate': true,
          'event_datetime': '2024-01-04T10:00:00+00:00',
          if (url != null) 'certificate_url': url,
          if (number != null) 'certificate_no': number,
        };

    test('certificate_no and certificate_url, as sent', () {
      final c = Certificate.fromEventJson(row(
        url: 'https://myotherapp.in/certificates/$publicId',
        number: 'CERT-4TQ8B-ZKM2R',
      ))!;
      expect(c.number, 'CERT-4TQ8B-ZKM2R');
      expect(c.shareUrl, 'https://myotherapp.in/certificates/$publicId');
      expect(c.publicId, publicId);
      expect(c.verifyCode, 'CERT-4TQ8B-ZKM2R');
      // Kept for the signed-in fetches only.
      expect(c.ticketId, 'MOA-4KD9W-22XQZ');
    });

    test('never made from the ticket id: none sent is none shown', () {
      final c = Certificate.fromEventJson(row())!;
      expect(c.number, isNull);
      expect(c.shareUrl, isNull);
      expect(c.publicId, isNull);
      expect(c.verifyCode, isNull);
      expect(c.publicPdfUrl('https://api.example.test/api/v1'), isNull);
    });

    test('an older address by ticket id is not a page to share', () {
      // A list saved on the phone before the server changed.
      final c = Certificate.fromEventJson(row(
        url: 'https://myotherapp.in/certificates/MOA-4KD9W-22XQZ',
      ))!;
      expect(c.shareUrl, isNull);
      expect(c.publicId, isNull);
      expect(c.number, isNull);
    });

    test('a number but no page: checked by its number, shared by nothing',
        () {
      final c = Certificate.fromEventJson(row(number: 'CERT-4TQ8B-ZKM2R'))!;
      expect(c.shareUrl, isNull);
      expect(c.verifyCode, 'CERT-4TQ8B-ZKM2R');
    });

    test('a blank or non-string field reads as none', () {
      final c = Certificate.fromEventJson(row(url: 42, number: '  '))!;
      expect(c.number, isNull);
      expect(c.shareUrl, isNull);
    });

    test("the PDF the browser may open is the public one, by public id", () {
      final c = Certificate.fromEventJson(row(
        url: 'https://myotherapp.in/certificates/$publicId',
      ))!;
      expect(
        c.publicPdfUrl('https://api.example.test/api/v1'),
        'https://api.example.test/api/v1/events/certificates/$publicId/pdf',
      );
    });
  });

  group('where VIEW CERTIFICATE goes', () {
    const publicId = 'q7Lk2Vb9_xR4mT0aZ-c8NwPe';

    test('a public id is 24 URL-safe characters; a ticket id is not one', () {
      expect(isCertificatePublicId(publicId), isTrue);
      expect(isCertificatePublicId('MOA-4KD9W-22XQZ'), isFalse);
      expect(isCertificatePublicId('CERT-4TQ8B-ZKM2R'), isFalse);
      expect(isCertificatePublicId('${publicId}x'), isFalse);
      expect(isCertificatePublicId(null), isFalse);
    });

    test('by public id, the public route; by an older ticket id, the '
        "person's own screen", () {
      expect(
          certificateLocationFor('https://myotherapp.in/certificates/$publicId'),
          '/certificates/$publicId');
      expect(
          certificateLocationFor(
              'https://myotherapp.in/certificates/MOA-4KD9W-22XQZ'),
          '/profile/certificates/MOA-4KD9W-22XQZ');
      expect(certificateLocationFor(null), isNull);
      expect(certificateLocationFor('https://myotherapp.in/tickets/MOA-1'),
          isNull);
    });
  });

  group('search', () {
    final all = [
      cert(ticketId: 'a', name: 'Blender Workshop', club: 'IEDC CET'),
      cert(ticketId: 'b', name: 'Oasis Hackathon', club: 'Tinkerhub',
          type: 'Hackathon'),
    ];

    List<Certificate> search(String q) => applyCertificateFilters(
          all,
          query: q,
          sort: CertificateSort.newest,
        );

    test('matches the event name', () {
      expect(search('blender').single.ticketId, 'a');
    });

    test('matches the club, which is on the card too', () {
      expect(search('tinkerhub').single.ticketId, 'b');
    });

    test('matches the event type', () {
      expect(search('hackathon').single.ticketId, 'b');
    });

    test('is case insensitive and ignores surrounding space', () {
      expect(search('  OASIS  ').single.ticketId, 'b');
    });

    test('an empty query keeps everything', () {
      expect(search('   '), hasLength(2));
    });
  });

  group('sort', () {
    final all = [
      cert(ticketId: 'old', name: 'Zebra Event', club: 'Zulu',
          on: DateTime(2023, 1, 1)),
      cert(ticketId: 'new', name: 'Alpha Event', club: 'Alpha',
          on: DateTime(2025, 1, 1)),
    ];

    List<String> order(CertificateSort sort) => applyCertificateFilters(
          all,
          query: '',
          sort: sort,
        ).map((c) => c.ticketId).toList();

    test('newest first is the default order', () {
      expect(order(CertificateSort.newest), ['new', 'old']);
    });

    test('oldest first reverses it', () {
      expect(order(CertificateSort.oldest), ['old', 'new']);
    });

    test('by name', () {
      expect(order(CertificateSort.nameAZ), ['new', 'old']);
    });

    test('by club', () {
      expect(order(CertificateSort.clubAZ), ['new', 'old']);
    });

    test('sorting does not mutate the list it was given', () {
      final input = [...all];
      applyCertificateFilters(input, query: '', sort: CertificateSort.oldest);

      expect(input.map((c) => c.ticketId), ['old', 'new']);
    });
  });

  group('the pinned tab', () {
    final all = [cert(ticketId: 'a'), cert(ticketId: 'b')];

    test('shows only what is pinned', () {
      final result = applyCertificateFilters(
        all,
        query: '',
        sort: CertificateSort.newest,
        onlyPinned: {'b'},
      );

      expect(result.single.ticketId, 'b');
    });

    test('nothing pinned means an empty tab, not everything', () {
      final result = applyCertificateFilters(
        all,
        query: '',
        sort: CertificateSort.newest,
        onlyPinned: <String>{},
      );

      expect(result, isEmpty);
    });
  });
}

// --- style parsing -----------------------------------------------------------
// Appended: the preview is drawn from this config, so a malformed colour or
// a missing field must degrade rather than take the screen down.
