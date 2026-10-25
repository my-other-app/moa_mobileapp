import 'package:finnet/features/volunteer/data/ticket_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a code typed at the door looks like. Only a ticket code checks
/// anyone in; an admission number finds whose it is (the door console's
/// scan, gate_console_test.dart).
void main() {
  group('what a typed code looks like', () {
    test('ticket codes, new and old, and registration ids', () {
      expect(looksLikeTicketCode(ticketCodeExample), isTrue);
      expect(looksLikeTicketCode(' moa-7k3qf-x9pwm '), isTrue);
      // Older tickets: MOA-, the time in hex, five letters.
      expect(looksLikeTicketCode('MOA-3F2A9C-K7QXD'), isTrue);
      expect(looksLikeTicketCode('MOA-1A-K7QXD'), isTrue);
      expect(
          looksLikeTicketCode('0b7c2a3e-5d4f-4a8e-9c1b-2f3e4d5a6b7c'), isTrue);

      expect(looksLikeTicketCode('MOA-0042-E12'), isFalse);
      expect(looksLikeTicketCode('hello'), isFalse);
    });

    test('admission numbers, in every shape an event can give them', () {
      expect(looksLikeAdmissionNumber('MOA-0042-E12'), isTrue);
      expect(looksLikeAdmissionNumber('moa-0042-e12'), isTrue);
      expect(looksLikeAdmissionNumber('MOA-0042'), isTrue); // no event code
      expect(looksLikeAdmissionNumber('TEDX-KOCHI-00042-E7'), isTrue);
      expect(looksLikeAdmissionNumber('MOA-12345-E1234'), isTrue);
      expect(looksLikeAdmissionNumber('A12-E7'), isTrue); // a seat
    });

    test('a ticket code is never taken for an admission number', () {
      expect(looksLikeAdmissionNumber(ticketCodeExample), isFalse);
      // All digits in the middle, as a new code can be.
      expect(looksLikeAdmissionNumber('MOA-23456-X9PWM'), isFalse);
      // An old code whose last group reads like an event code.
      expect(looksLikeAdmissionNumber('MOA-3F2A9C-E2345'), isFalse);
      expect(looksLikeAdmissionNumber('hello'), isFalse);
      expect(looksLikeAdmissionNumber(''), isFalse);
    });
  });
}
