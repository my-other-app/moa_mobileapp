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
    test('an attended registration becomes one', () {
      final result = Certificate.fromEventJson(const {
        'id': 7,
        'name': 'Oasis Hackathon',
        'ticket_id': 'MOA-4KD9W-22XQZ',
        'is_attended': true,
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

  group('the pdf url', () {
    test('points at the certificate endpoint for this ticket', () {
      expect(
        cert(ticketId: 'MOA-9').pdfUrl('https://api.example.test/api/v1'),
        'https://api.example.test/api/v1/events/certificates/MOA-9/pdf',
      );
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
