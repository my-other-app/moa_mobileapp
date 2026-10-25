/// The number WhatsApp would be sent to, as the server reads it
/// (`app/core/whatsapp.py` `normalise`, and the website's `whatsappNumber`),
/// or null when it can't be: "98765 43210" is "+919876543210".
///
/// Without a country code it is taken as Indian: ten digits from 6 to 9, or
/// those after a 0 or 91. With one (`+` or `00`), 7 to 15 digits, and an
/// Indian mobile after +91. A landline is a phone number, but not this.
String? whatsappNumber(String? phone) {
  var s = (phone ?? '').trim().replaceAll(RegExp(r'[\s\-(). /]'), '');
  if (s.isEmpty) return null;
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('+')) {
    final d = s.substring(1);
    if (!_digits.hasMatch(d)) return null;
    if (d.startsWith('91')) {
      return _indianMobile.hasMatch(d.substring(2)) ? '+$d' : null;
    }
    return d.length >= 7 && d.length <= 15 && !d.startsWith('0') ? '+$d' : null;
  }
  if (!_digits.hasMatch(s)) return null;
  if (s.length == 11 && s.startsWith('0')) {
    s = s.substring(1);
  } else if (s.length == 12 && s.startsWith('91')) {
    s = s.substring(2);
  }
  return _indianMobile.hasMatch(s) ? '+91$s' : null;
}

final _digits = RegExp(r'^\d+$');
final _indianMobile = RegExp(r'^[6-9]\d{9}$');
