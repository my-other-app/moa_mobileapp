/// What a volunteer can type at the door, and what they can't.
///
/// Only the ticket code checks anyone in: `MOA-7K3QF-X9PWM` -- two groups
/// of five from an alphabet without 0/O or 1/I/L -- or, on older tickets,
/// `MOA-`, up to seven hex digits, then five of those letters
/// (`MOA-3F2A9C-K7QXD`). The registration's id works too.
///
/// The admission number printed beside the QR (`MOA-0042-E123`) does not:
/// those run in sequence, so anyone could print a QR for one. The door
/// console's scan answers it with whose it is (`hint: ADMISSION_NUMBER`),
/// for the volunteer to check them in by hand.
library;

/// A ticket code, for copy that asks for one: made of [_alphabet], as a
/// real one is, so it never reads as a code that could not exist.
const ticketCodeExample = 'MOA-7K3QF-X9PWM';

const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

final _ticketCode = RegExp('^MOA-[$_alphabet]{5}-[$_alphabet]{5}\$');

/// The time part was `format(ms % 36**5, "X")`: hex, no leading zero.
final _olderTicketCode = RegExp('^MOA-[1-9A-F][0-9A-F]{0,6}-[$_alphabet]{5}\$');

final _registrationId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false);

/// PREFIX-0042-E123, PREFIX-0042, or a seat with the event's code (A12-E123).
/// The prefix is the event's own: letters, digits and single dashes.
final _admissionNumber = RegExp(r'^(?:[A-Z0-9]+-)+(?:\d+(?:-E\d+)?|E\d+)$');

/// [text] is shaped like a ticket code, or a registration id.
bool looksLikeTicketCode(String text) {
  final code = text.trim().toUpperCase();
  return _ticketCode.hasMatch(code) ||
      _olderTicketCode.hasMatch(code) ||
      _registrationId.hasMatch(code);
}

/// [text] is shaped like an admission number and not like a ticket code.
bool looksLikeAdmissionNumber(String text) {
  final code = text.trim().toUpperCase();
  return !looksLikeTicketCode(code) && _admissionNumber.hasMatch(code);
}
