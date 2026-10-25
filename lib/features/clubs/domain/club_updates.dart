/// "Get updates from `<club>` on WhatsApp": a yes to the club's own
/// broadcasts, from the club's own WhatsApp number.
///
/// Meta's opt-in rule is that the box names the business, so these are
/// exactly the words the server keeps with the yes
/// (`app/api/club_whatsapp/consent.py` `text_for`) and the website shows.
/// The box is unticked until the person ticks it, and shown only for a club
/// whose payload says `whatsapp_updates: true`: from a server without the
/// flag, nothing shows.
String clubUpdatesText(String clubName) {
  final name = clubName.trim();
  return 'Get updates from ${name.isEmpty ? 'this club' : name} on WhatsApp';
}

/// The `error_code` of a registration refused because the box was ticked
/// with a number WhatsApp can't reach (`errors.phone` says why).
const whatsappNumberErrorCode = 'WHATSAPP_NUMBER';

/// What the phone field says when WhatsApp can't reach its number.
const whatsappNumberProblem =
    "WhatsApp can't reach this number. Enter a mobile number, or untick the "
    'WhatsApp box.';
