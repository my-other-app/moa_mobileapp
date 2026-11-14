import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'network_fixtures.dart';

void main() {
  group('a public profile', () {
    test('reads every part, and only the safe links', () {
      final p = PublicProfile.fromJson(publicProfileJson())!;
      expect(p.handle, 'ananya');
      expect(p.userId, 42);
      expect(p.initials, 'AI');
      expect(p.org!.name, 'CET Trivandrum');
      expect(p.interests.single.emoji, '💙');
      expect(p.links.map((l) => l.type), ['github', 'website']);
      expect(p.links.last.uri.toString(), 'https://ananya.dev');
      expect(p.links.last.title, 'My blog');
      expect(p.links.first.title, 'GitHub');
      final project = p.projects.single;
      expect(project.image, 'https://media.myotherapp.in/p/7.jpg');
      expect(project.month, DateTime(2026, 8));
      expect(project.tags, ['flutter', 'firebase']);
      expect(p.achievements.eventsAttended, 12);
      expect(p.achievements.talks!.single.eventRoute, '/events/hack-night');
      expect(p.achievements.clubs, isNull);
      expect(p.email, isNull);
      expect(p.relation, isNull);
      expect(p.publicUri.toString(), 'https://myotherapp.in/u/ananya');
    });

    test('a private one seen by a stranger is locked until they save back', () {
      final stranger =
          PublicProfile.fromJson(publicProfileJson(private: true))!;
      expect(stranger.locked, isTrue);
      final savedBack = PublicProfile.fromJson(publicProfileJson(
          private: true,
          relation: {'saved_by_me': true, 'saved_me': true, 'mutual': true}))!;
      expect(savedBack.locked, isFalse);
      expect(savedBack.relation!.mutual, isTrue);
    });

    test('nonsense is no profile, never a crash', () {
      expect(PublicProfile.fromJson('nope'), isNull);
      expect(PublicProfile.fromJson({'full_name': 'No handle'}), isNull);
      final bare = PublicProfile.fromJson({'handle': 'A.B'})!;
      expect(bare.handle, 'a.b');
      expect(bare.fullName, 'a.b');
      expect(bare.links, isEmpty);
      expect(bare.achievements.isEmpty, isTrue);
    });
  });

  group('my profile', () {
    test('its settings, completeness and own contact', () {
      final me = MyProfile.fromJson(myProfileJson())!;
      expect(me.profile.isMe, isTrue);
      expect(me.settings.audienceOf('projects'), Audience.met);
      expect(me.settings.audienceOf('links'), Audience.everyone);
      expect(me.settings.shareEmail, ContactShare.mutual);
      expect(me.settings.sharePhone, ContactShare.nobody);
      expect(me.settings.showTalks, isTrue);
      expect(me.settings.showEvents, isFalse);
      expect(me.completeness.score, 50);
      expect(me.completeness.missing, ['links', 'projects']);
      expect(me.email, 'asha@example.com');
      expect(me.settings.visibilityJson({'links': Audience.me}), {
        'links': 'me',
        'projects': 'met',
        'achievements': 'everyone',
        'interests': 'everyone',
        'org': 'everyone',
      });
    });

    test('settings the server leaves out take the contract defaults', () {
      final s = ProfileSettings.fromJson(null);
      expect(s.audienceOf('links'), Audience.everyone);
      expect(s.shareEmail, ContactShare.nobody);
      expect(s.notifySaves, isTrue);
      expect(s.scanningEnabled, isTrue);
      expect(s.showCertificates, isTrue);
      expect(s.showClubs, isFalse);
      expect(s.indexable, isFalse);
    });

    test('a project goes back as the server takes it', () {
      final project = ProfileProject(
        title: 'Club app',
        uri: Uri.parse('https://x.dev'),
        month: DateTime(2026, 3),
        tags: const ['a'],
      );
      expect(project.toJson(), {
        'title': 'Club app',
        'summary': null,
        'url': 'https://x.dev',
        'tags': ['a'],
        'role': null,
        'month': '2026-03-01',
      });
    });
  });

  group('links', () {
    test('a pasted link picks its own type', () {
      String type(String url) => profileLinkTypeFor(profileLinkUri(url)!);
      expect(type('linkedin.com/in/asha'), 'linkedin');
      expect(type('https://www.github.com/asha'), 'github');
      expect(type('https://www.behance.net/asha'), 'behance');
      expect(type('https://twitter.com/asha'), 'x');
      expect(type('https://youtu.be/xyz'), 'youtube');
      expect(type('https://asha.dev'), 'website');
    });

    test('only http(s) links without credentials are kept', () {
      expect(profileLinkUri('javascript:alert(1)'), isNull);
      expect(profileLinkUri('data:text/html,hi'), isNull);
      expect(profileLinkUri('https://user:pw@evil.com'), isNull);
      expect(profileLinkUri('not a link'), isNull);
      expect(profileLinkUri('https://${'a' * 500}.com'), isNull);
      expect(profileLinkUri('asha.dev').toString(), 'https://asha.dev');
    });
  });

  group('the network', () {
    test('a person, their encounters and the events they were met at', () {
      final p = NetworkPerson.fromJson(
          networkPersonJson(note: ' Talk about Riverpod ', tags: ['flutter']))!;
      expect(p.person.handle, 'ananya');
      expect(p.person.route, '/u/ananya');
      expect(p.person.line, 'Flutter dev · CET');
      expect(p.note, 'Talk about Riverpod');
      expect(p.tags, ['flutter']);
      expect(p.encounters.single.method, MetHow.qr);
      expect(p.events.single.name, 'DevFest');
      expect(p.events.single.route, '/events/devfest-2026');
    });

    test('a list with its filters', () {
      final list = NetworkList.fromJson(networkListJson([
        networkPersonJson(),
        {'id': null},
        networkPersonJson(id: 6, atEvent: false),
      ]));
      expect(list.items, hasLength(2));
      expect(list.events.single.count, 3);
      expect(list.eventCount(9)!.event.name, 'DevFest');
      expect(list.tags.single.tag, 'flutter');
      expect(list.items.last.events, isEmpty);
    });

    test('a query: A to Z reads up, the rest newest first', () {
      expect(const NetworkQuery(sort: NetworkSort.name).toParams(), {
        'sort': 'name',
        'order': 'asc',
        'page': 1,
        'page_size': 50,
      });
      expect(
          const NetworkQuery(q: ' riya ', eventId: 9, mutualOnly: true)
              .toParams(),
          {
            'q': 'riya',
            'event_id': 9,
            'mutual': true,
            'sort': 'recent',
            'order': 'desc',
            'page': 1,
            'page_size': 50,
          });
      expect(const NetworkQuery(eventId: 9), const NetworkQuery(eventId: 9));
      expect(const NetworkQuery(eventId: 9).copyWith(clearEvent: true).eventId,
          isNull);
    });

    test('a save, and who saved me', () {
      final saved = SaveResult.fromJson(saveResultJson(mutual: true))!;
      expect(saved.person.mutual, isTrue);
      expect(saved.profile!.relation!.networkId, 5);
      final entries = SavedMeEntry.listFrom({
        'items': [
          {
            'person': personBriefJson(),
            'saved_at': '2026-11-28T10:00:00Z',
            'event': devFest(),
          },
          {
            'person': {'full_name': null}
          },
        ],
        'total': 2,
      });
      expect(entries.first.event!.id, 9);
      expect(entries.last.person.fullName, 'Deleted user');
      expect(entries.last.person.route, isNull);
    });

    test('my QR', () {
      final qr = MyQr.fromJson({
        'code': 'abcdefghjk',
        'url': 'https://myotherapp.in/p/abcdefghjk',
        'created_at': '2026-11-14T10:00:00Z',
      })!;
      expect(qr.url, 'https://myotherapp.in/p/abcdefghjk');
      expect(MyQr.fromJson({'code': 'x'}), isNull);
    });
  });

  group('a scanned code', () {
    test('a personal QR, its link or the bare code', () {
      expect(readScannedCode('https://myotherapp.in/p/abcdefghjk'),
          isA<PersonalCode>().having((c) => c.code, 'code', 'abcdefghjk'));
      expect(readScannedCode('https://www.myotherapp.in/p/ABCDEFGHJK/'),
          isA<PersonalCode>().having((c) => c.code, 'code', 'abcdefghjk'));
      expect(readScannedCode('abcdefghjk'), isA<PersonalCode>());
      expect(isPersonalCode('https://myotherapp.in/p/abcdefghjk'), isTrue);
    });

    test('a profile link', () {
      expect(readScannedCode('https://myotherapp.in/u/ananya'),
          isA<ProfileHandleCode>().having((c) => c.handle, 'h', 'ananya'));
    });

    test("a ticket is a ticket, and nothing more is read from it", () {
      expect(readScannedCode('MOA-7K3QF-X9PWM'), isA<TicketScanned>());
      expect(readScannedCode('https://myotherapp.in/tickets/MOA-7K3QF-X9PWM'),
          isA<TicketScanned>());
      expect(isPersonalCode('MOA-7K3QF-X9PWM'), isFalse);
    });

    test('anything else, and look-alike letters, are not codes', () {
      expect(
          readScannedCode('https://evil.com/p/abcdefghjk'), isA<OtherCode>());
      expect(readScannedCode('abcdefgh10'), isA<OtherCode>());
      expect(readScannedCode('hello'), isA<OtherCode>());
      expect(readScannedCode(''), isA<OtherCode>());
    });
  });

  group('a handle', () {
    test('the rules', () {
      expect(handleProblem('asha'), isNull);
      expect(handleProblem('asha.menon_2'), isNull);
      expect(handleProblem('as'), isNotNull);
      expect(handleProblem('a' * 31), isNotNull);
      expect(handleProblem('Asha'), isNotNull);
      expect(handleProblem('.asha'), isNotNull);
      expect(handleProblem('asha-'), isNotNull);
      expect(handleProblem('as..ha'), isNotNull);
      expect(handleProblem('asha menon'), isNotNull);
      expect(handleProblem('admin'), 'That one is reserved.');
      expect(handleProblem('events'), 'That one is reserved.');
    });
  });

  group('the pushes', () {
    test('saves open who saved me; the recap, the network at the event', () {
      expect(
          networkPushRoute(networkSavesType, 9), '/network/saved-me?event=9');
      expect(networkPushRoute(networkSavesType, null), '/network/saved-me');
      expect(networkPushRoute(networkRecapType, 9), '/network?event=9');
      expect(networkPushRoute(networkRecapType, null), '/network');
      expect(networkPushRoute('event_reminder', 9), isNull);
    });
  });
}
