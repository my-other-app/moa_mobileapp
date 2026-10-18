import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/utils/share_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('imageUrlFrom', () {
    test('null is no image, not a crash', () {
      expect(imageUrlFrom(null), isNull);
    });

    test('takes the thumbnail from the S3 dict', () {
      expect(
        imageUrlFrom(const {
          'thumbnail': 'https://img/t.png',
          'medium': 'https://img/m.png',
          'original': 'https://img/o.png',
        }),
        'https://img/t.png',
      );
    });

    test('falls back to the next size when the thumbnail is missing', () {
      expect(
        imageUrlFrom(const {'thumbnail': null, 'medium': 'https://img/m.png'}),
        'https://img/m.png',
      );
      expect(
        imageUrlFrom(const {'thumbnail': '', 'original': 'https://img/o.png'}),
        'https://img/o.png',
      );
    });

    test('an older row with a bare URL is read as that URL', () {
      expect(imageUrlFrom('  https://img/x.png '), 'https://img/x.png');
    });

    test('empty and odd shapes are no image', () {
      expect(imageUrlFrom(''), isNull);
      expect(imageUrlFrom(const <String, dynamic>{}), isNull);
      expect(imageUrlFrom(const {'thumbnail': 42}), isNull);
      expect(imageUrlFrom(7), isNull);
      expect(imageUrlFrom(const ['https://img/x.png']), isNull);
    });

    test('a caller can ask for a bigger size first', () {
      expect(
        imageUrlFrom(
          const {'thumbnail': 't', 'large': 'l'},
          prefer: const ['large', 'thumbnail'],
        ),
        'l',
      );
    });
  });

  group('clubShareUrl', () {
    test("is the club's page on the public site", () {
      expect(
        clubShareUrl(slug: 'tinkerhub-cet', id: 5),
        'https://myotherapp.in/clubs/tinkerhub-cet',
      );
    });

    test('falls back to the id without a slug', () {
      expect(clubShareUrl(slug: '', id: 5), 'https://myotherapp.in/clubs/5');
      expect(clubShareUrl(slug: null, id: 5), 'https://myotherapp.in/clubs/5');
    });

    test('is null with nothing to link to', () {
      expect(clubShareUrl(slug: ' ', id: null), isNull);
      expect(clubShareUrl(slug: null, id: 0), isNull);
    });

    test('escapes a slug that is not path-safe', () {
      expect(
        clubShareUrl(slug: 'a b/c'),
        'https://myotherapp.in/clubs/a%20b%2Fc',
      );
    });
  });

  group('the links Settings opens', () {
    test('point at the public site and the team inbox', () {
      expect(privacyPolicyUri.toString(), 'https://myotherapp.in/privacy');
      expect(termsUri.toString(), 'https://myotherapp.in/terms');
      expect(websiteUri.toString(), 'https://myotherapp.in');
      expect(supportEmailUri.scheme, 'mailto');
      expect(supportEmailUri.path, 'support@myotherapp.in');
    });
  });
}
