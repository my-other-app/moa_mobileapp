import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/auth/jwt_claims.dart';
import 'package:finnet/core/services/crash_reporting.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nothing names a person in Analytics or Crashlytics', () {
    test('handles, codes and network rows keep their shape, not the person',
        () {
      expect(
          redactForCrashReport('/profiles/ananya.iyer'), '/profiles/:handle');
      expect(redactForCrashReport('/profiles/ananya/vcard'),
          '/profiles/:handle/vcard');
      expect(redactForCrashReport('/profiles/by-code/abcdefghjk'),
          '/profiles/by-code/:code');
      expect(redactForCrashReport('/network/42'), '/network/:id');
      expect(redactForCrashReport('API Error: /network/42 - 404'),
          'API Error: /network/:id - 404');
      expect(redactForCrashReport('opened https://myotherapp.in/u/asha?x=1'),
          'opened https://myotherapp.in/u/:handle?x=1');
      expect(redactForCrashReport('/p/abcdefghjk'), '/p/:code');
    });

    test('the rest of an address is left alone', () {
      expect(redactForCrashReport('/network'), '/network');
      expect(redactForCrashReport('/network/saved-me'), '/network/saved-me');
      expect(redactForCrashReport('/network/export'), '/network/export');
      expect(redactForCrashReport('/user/profile/me'), '/user/profile/me');
      expect(redactForCrashReport('/me/profile/projects/3'),
          '/me/profile/projects/3');
    });
  });

  test('a handle with a dot is a profile, not a file', () {
    expect(webLocation(Uri.parse('https://myotherapp.in/u/asha.rao')),
        '/u/asha.rao');
    // Files are still files.
    expect(webLocation(Uri.parse('https://myotherapp.in/events/feed.xml')),
        isNull);
  });

  test("a token's account", () {
    // {"user_id": 7, "sid": "s"} as a JWT's payload.
    const token = 'x.eyJ1c2VyX2lkIjo3LCJzaWQiOiJzIn0.y';
    expect(userIdOf(token), 7);
    expect(userIdOf('not-a-jwt'), isNull);
    expect(userIdOf(null), isNull);
  });

  test("the bar's tab for an address", () {
    expect(tabIndexFor('/'), 0);
    expect(tabIndexFor('/events'), 1);
    expect(tabIndexFor('/network'), 2);
    expect(tabIndexFor('/clubs'), 3);
    expect(tabIndexFor('/profile'), 4);
    expect(tabIndexFor('/network/5'), isNull);
    expect(tabIndexFor('/events/hack-night'), isNull);
  });
}
