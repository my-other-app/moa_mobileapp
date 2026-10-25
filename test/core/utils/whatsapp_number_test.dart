import 'package:finnet/core/utils/whatsapp_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'reads a number as the server does: India without a country code, '
      'anyone with one', () {
    expect(whatsappNumber('98765 43210'), '+919876543210');
    expect(whatsappNumber('9876543210'), '+919876543210');
    expect(whatsappNumber('098765-43210'), '+919876543210');
    expect(whatsappNumber('919876543210'), '+919876543210');
    expect(whatsappNumber('+91 98765 43210'), '+919876543210');
    expect(whatsappNumber('0091 9876543210'), '+919876543210');
    expect(whatsappNumber('(+1) 650-555-1234'), '+16505551234');
  });

  test('a landline, a short number or a typo is not one WhatsApp reaches', () {
    for (final bad in [
      '',
      null,
      '12345',
      '5876543210',
      '+91 5876543210',
      '080 2233 445',
      '0802233445',
      '98765O4321',
      '+0123456789',
    ]) {
      expect(whatsappNumber(bad), isNull, reason: '$bad');
    }
  });
}
