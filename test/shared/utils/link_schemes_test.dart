import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late List<Uri> launched;

  Future<bool> launch(Uri uri, LaunchMode mode) async {
    launched.add(uri);
    return true;
  }

  setUp(() => launched = []);

  group('a link outside the app opens when it is', () {
    for (final link in [
      'https://instagram.com/club',
      'http://example.org/page',
      'mailto:hello@club.org',
      'tel:+919876543210',
      'https://wa.me/919876543210',
      'https://www.google.com/maps/search/?api=1&query=Kochi',
    ]) {
      test(link, () async {
        expect(await openExternally(Uri.parse(link), launch: launch), isTrue);
        expect(launched, [Uri.parse(link)]);
      });
    }
  });

  group('any other scheme is not opened, and says so (false)', () {
    for (final link in [
      'upi://pay?pa=someone@bank&am=500',
      'intent://scan/#Intent;scheme=zxing;end',
      'javascript:alert(1)',
      'file:///etc/hosts',
      'sms:+919876543210',
      'whatsapp://send?phone=919876543210',
      'otherapp://open',
      'data:text/html,hi',
      'www.club.org', // no scheme at all
    ]) {
      test(link, () async {
        expect(await openExternally(Uri.parse(link), launch: launch), isFalse);
        expect(launched, isEmpty);
      });
    }
  });

  test('the scheme is matched whatever its case', () {
    expect(isOpenableLink(Uri.parse('HTTPS://example.org')), isTrue);
    expect(isOpenableLink(Uri(scheme: 'MailTo', path: 'a@b.c')), isTrue);
    expect(isOpenableLink(Uri.parse('UPI://pay')), isFalse);
  });

  test('inside the app, only web pages', () async {
    expect(
        await openInAppThenBrowser(Uri.parse('mailto:a@b.c'), launch: launch),
        isFalse);
    expect(await openInAppThenBrowser(Uri.parse('upi://pay'), launch: launch),
        isFalse);
    expect(launched, isEmpty);

    expect(
        await openInAppThenBrowser(Uri.parse('https://myotherapp.in/terms'),
            launch: launch),
        isTrue);
  });

  test('the app\'s own links still open: support mail, the policies', () async {
    for (final uri in [supportEmailUri, privacyPolicyUri, helpCentreUri]) {
      expect(await openExternally(uri, launch: launch), isTrue);
    }
  });
}
