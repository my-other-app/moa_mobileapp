import 'package:finnet/features/clubs/data/models/club_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'club_fixtures.dart';

void main() {
  group('reading a club\'s people and numbers', () {
    test("the club detail's handles become links, as the website makes them",
        () {
      final club = ClubInfo.fromJson(clubInfoJson(team: [
        {
          'name': 'Asha Menon',
          'instagram': '@asha_m',
          'x': 'asha',
          'linkedin': 'asha-menon',
          'website': 'asha',
        },
        {
          'name': 'Rahul Nair',
          'instagram': 'instagram.com/rahul',
          'x': 'javascript:alert(1)',
          'linkedin': 'https://www.linkedin.com/in/rahul/',
          'website': 'rahul.dev',
        },
      ]));
      final asha = club.team.first;
      expect(asha.instagram, 'https://instagram.com/asha_m');
      expect(asha.x, 'https://x.com/asha');
      expect(asha.linkedin, 'https://linkedin.com/in/asha-menon');
      // A word that is not a website is not a link.
      expect(asha.website, isNull);
      final rahul = club.team.last;
      expect(rahul.instagram, 'https://instagram.com/rahul');
      expect(rahul.x, isNull);
      expect(rahul.linkedin, 'https://www.linkedin.com/in/rahul/');
      expect(rahul.website, 'https://rahul.dev');
    });

    test(
        'a bio, and a partner\'s website and words, when the server sends them',
        () {
      final club = ClubInfo.fromJson(clubInfoJson(team: [
        {'name': 'Asha', 'bio': '  Builds robots.  '},
      ], partners: [
        {
          'name': 'Acme',
          'website': 'acme.example',
          'description': 'Parts and a workshop.',
        },
      ]));
      expect(club.team.single.bio, 'Builds robots.');
      expect(club.partners.single.website, 'https://acme.example');
      expect(club.partners.single.description, 'Parts and a workshop.');
    });

    test('the followers count, under whichever name it comes', () {
      final info = clubInfoJson()..remove('followers_count');
      expect(ClubInfo.fromJson(info).followersCount, 0);
      expect(
          ClubInfo.fromJson({...info, 'follower_count': 7}).followersCount, 7);
      expect(ClubInfo.fromJson({...info, 'followers': 9}).followersCount, 9);
      expect(ClubInfo.fromJson(clubInfoJson(followers: 2560)).followersCount,
          2560);
      expect(
          ClubInfo.fromDiscoverJson(clubPublicJson(followers: 0))
              .followersCount,
          0);
    });
  });

  group("a club's updates on WhatsApp", () {
    test('offered only when the server says true, from either page', () {
      expect(
          ClubInfo.fromJson(clubInfoJson(whatsappUpdates: true))
              .whatsappUpdates,
          isTrue);
      expect(
          ClubInfo.fromJson(clubInfoJson(whatsappUpdates: false))
              .whatsappUpdates,
          isFalse);
      expect(ClubInfo.fromJson(clubInfoJson()).whatsappUpdates, isFalse);
      expect(
          ClubInfo.fromDiscoverJson(clubPublicJson(whatsappUpdates: true))
              .whatsappUpdates,
          isTrue);
      expect(
          ClubInfo.fromDiscoverJson(clubPublicJson()).whatsappUpdates, isFalse);
    });

    test("the person's own yes, from /clubs/info", () {
      expect(
          ClubInfo.fromJson(clubInfoJson(following: true, clubUpdates: true))
              .clubUpdatesWhatsapp,
          isTrue);
      expect(
          ClubInfo.fromJson(clubInfoJson(following: true)).clubUpdatesWhatsapp,
          isFalse);
      expect(ClubInfo.fromDiscoverJson(clubPublicJson()).clubUpdatesWhatsapp,
          isFalse);
    });
  });
}
