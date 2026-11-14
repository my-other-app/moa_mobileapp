/// Feature 4's addresses in the app, what a scanned code is, and the rules
/// a handle follows. Pure Dart: the router, the push table and the tests
/// read it without Flutter.
library;

import 'package:finnet/features/volunteer/data/ticket_code.dart';

/// A profile, by handle: the website's `/u/<handle>` too. Open signed out.
String profileRoute(String handle) => '/u/${Uri.encodeComponent(handle)}';

/// A personal QR's link, `/p/<code>`: opened signed in, it saves the person.
String profileCodeRoute(String code) => '/p/${Uri.encodeComponent(code)}';

/// The Network tab (signed in only).
const networkLocation = '/network';

/// The Network tab, showing who was met at one event: the recap's link.
String networkEventLocation(int eventId) => '/network?event=$eventId';

/// Who saved the person and hasn't been saved back: optionally one event's.
const savedMeLocation = '/network/saved-me';
String savedMeEventLocation(int eventId) => '$savedMeLocation?event=$eventId';

/// One person in the network.
String networkPersonRoute(int id) => '$networkLocation/$id';

/// The scanner's "Save a person" mode; at [eventId], the event the person
/// is at.
const savePersonScanLocation = '$networkLocation/scan';
String savePersonScanAt(int? eventId) => eventId == null
    ? savePersonScanLocation
    : '$savePersonScanLocation?event=$eventId';

/// My QR, full screen.
const myQrLocation = '/profile/qr';

/// Editing the public profile, and seeing it as a stranger does.
const editPublicProfileLocation = '/profile/public';
const strangerPreviewLocation = '/profile/public/preview';

/// "Ananya saved your profile at DevFest": batched per person and event
/// (`{type, event_id}`). Opens who saved them, to save back.
const networkSavesType = 'network_saves';

/// "You met 12 people at DevFest": the morning after (`{type, event_id}`).
/// Opens the Network tab at that event.
const networkRecapType = 'network_recap';

/// Where a network push opens; null for any other type.
String? networkPushRoute(String? type, int? eventId) => switch (type) {
      networkSavesType =>
        eventId == null ? savedMeLocation : savedMeEventLocation(eventId),
      networkRecapType =>
        eventId == null ? networkLocation : networkEventLocation(eventId),
      _ => null,
    };

/// A personal code's letters: `[a-z0-9]` without the look-alikes 0, o, 1,
/// l and i.
const profileCodeAlphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
final _profileCode = RegExp('^[$profileCodeAlphabet]{10}\$');

/// [text] is shaped like a personal code.
bool looksLikeProfileCode(String text) =>
    _profileCode.hasMatch(text.trim().toLowerCase());

/// The site's hosts: the apex and the two that redirect to it.
bool _isSite(String host) {
  final h = host.toLowerCase();
  return h == 'myotherapp.in' ||
      h == 'www.myotherapp.in' ||
      h == 'events.myotherapp.in';
}

/// What the scanner read.
sealed class ScannedCode {
  const ScannedCode();
}

/// A personal QR: `https://myotherapp.in/p/<code>`, or the bare code.
class PersonalCode extends ScannedCode {
  const PersonalCode(this.code);
  final String code;
}

/// A link to someone's profile, `https://myotherapp.in/u/<handle>`.
class ProfileHandleCode extends ScannedCode {
  const ProfileHandleCode(this.handle);
  final String handle;
}

/// A ticket: never read further, never shown.
class TicketScanned extends ScannedCode {
  const TicketScanned();
}

/// Anything else.
class OtherCode extends ScannedCode {
  const OtherCode();
}

/// What [raw] is, for the "Save a person" scanner and the door.
ScannedCode readScannedCode(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const OtherCode();
  final uri = Uri.tryParse(text);
  if (uri != null &&
      (uri.isScheme('https') || uri.isScheme('http')) &&
      _isSite(uri.host)) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length == 2) {
      final head = segments.first.toLowerCase();
      final value = segments[1];
      if (head == 'p' && looksLikeProfileCode(value)) {
        return PersonalCode(value.toLowerCase());
      }
      if (head == 'u' && handleProblem(normalHandle(value)) == null) {
        return ProfileHandleCode(normalHandle(value));
      }
      if (head == 'tickets') return const TicketScanned();
    }
    return const OtherCode();
  }
  if (looksLikeTicketCode(text)) return const TicketScanned();
  if (looksLikeProfileCode(text)) return PersonalCode(text.toLowerCase());
  return const OtherCode();
}

/// [raw] is a personal QR rather than a ticket: what the door scanner
/// says no to without asking the server.
bool isPersonalCode(String raw) => readScannedCode(raw) is PersonalCode;

/// Handles nobody may take: the backend's list exactly
/// (`app/api/profiles/rules.py` RESERVED) -- the contract's, the website's
/// top-level paths and files, and the API's own `by-code`. The server has
/// the last word (`HANDLE_RESERVED`); this only saves a round trip.
const reservedHandles = {
  // The contract's.
  'admin', 'api', 'app', 'me', 'u', 'p', 'help', 'support', 'about',
  'events', 'clubs', 'club', 'speakers', 'settings', 'login', 'signup',
  'register', 'myotherapp', 'official', 'null', 'undefined',
  // The website's top-level paths.
  'answers', 'certificates', 'claim', 'data-deletion', 'developers',
  'feedback', 'for-clubs', 'media', 'og', 'play', 'pricing', 'privacy',
  'requests', 'robots', 'robots.txt', 'sitemap', 'sitemap.xml', 'sitemaps',
  'terms', 'threads', 'tickets', 'topics', 'verify', 'manifest',
  'manifest.json', 'manifest.webmanifest', 'favicon.ico',
  'apple-touch-icon.png', 'brand', 'logo.svg', 'network', 'profiles',
  'profile', 'well-known', 'tests', 'error', 'not-found', 'global-error',
  'layout', 'page', 'providers', 'live', 'compete',
  // The API's own path under /profiles.
  'by-code',
};

/// A handle as the server stores and matches it: trimmed, a leading `@`
/// dropped, lower case.
String normalHandle(String raw) {
  var text = raw.trim();
  if (text.startsWith('@')) text = text.substring(1);
  return text.toLowerCase();
}

final _handleShape = RegExp(r'^[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?$');

/// Why [handle] (in its [normalHandle] form) can't be used, in words for
/// the person; null when it can. The server has the last word (a taken
/// handle only it knows).
String? handleProblem(String handle) {
  final h = handle.trim();
  if (h.length < 3) return 'At least 3 characters.';
  if (h.length > 30) return 'At most 30 characters.';
  if (h != h.toLowerCase()) return 'Lowercase letters only.';
  if (!_handleShape.hasMatch(h)) {
    return 'Letters, numbers, dots, dashes and underscores; '
        'start and end with a letter or number.';
  }
  if (h.contains('..')) return 'No two dots in a row.';
  if (reservedHandles.contains(h)) return 'That one is reserved.';
  return null;
}
