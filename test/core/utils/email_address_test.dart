import 'package:finnet/core/utils/email_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real addresses pass: plus tags, long TLDs, country domains', () {
    for (final ok in [
      'asha@example.com',
      'name+tag@gmail.com',
      'asha.menon@college.academy',
      'devfest@gdg.technology',
      'x@mail.co.in',
      "o'brien@example.ie",
      '  padded@example.com  ',
    ]) {
      expect(looksLikeEmail(ok), isTrue, reason: ok);
    }
  });

  test('what is not an address does not', () {
    for (final bad in [
      '',
      'asha',
      'asha@',
      '@example.com',
      'asha@example',
      'asha@example.c',
      'asha@@example.com',
      'asha menon@example.com',
      'asha@example.',
      'asha@.example.com',
    ]) {
      expect(looksLikeEmail(bad), isFalse, reason: bad);
    }
  });
}
