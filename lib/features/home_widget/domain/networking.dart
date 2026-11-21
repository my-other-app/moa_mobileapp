import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart' show siteLink;
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart' show initialsOf;

/// What the "Networking" home-screen widget shows (docs/HOME_WIDGETS.md):
/// the person's QR code to share, their name, and a quick way to scan
/// someone and to their network; on the large widget, the people they met
/// most recently.
///
/// It is written to storage the phone's lock screen and anyone holding the
/// phone can read, so it holds only what the widget shows and where a tap
/// goes: the version, the state, the person's name, the public profile
/// link their QR encodes (from `GET /me/qr`), how many people are in their
/// network, the taps' links, and for "Recently met" a few people's names,
/// initials and circle colours, the event they met at, how many have no
/// note yet, and -- only when the person turned photos on -- the name of
/// each one's small photo. Never a ticket, a token, an email or a phone
/// number, nor anyone's company, headline or note.

/// The widget's three faces.
enum NetworkingState {
  /// "Sign in to share your QR".
  signedOut('signed_out'),

  /// Signed in, but the app hasn't read the code yet (My QR makes it on
  /// the first ask): a calm placeholder that opens My QR.
  noQr('no_qr'),

  /// The code, drawn dark on white from [NetworkingSnapshot.profileLink].
  ready('ready');

  const NetworkingState(this.wire);

  /// As the widgets read it (NetworkingData.kt, NetworkingData.swift).
  final String wire;
}

/// Where the widget's taps go: the website's addresses for the app's
/// pages, read by the router as its own (`appLocationForLink`), with
/// sign-in first where needed. The QR and the card open My QR (full
/// screen), the Scan pill the scanner that saves a person, "Network · N"
/// the Network tab.
final networkingLinks = <String, String>{
  'qr': siteLink(myQrLocation),
  'scan': siteLink(savePersonScanLocation),
  'network': siteLink(networkLocation),
};

/// Whether [link] is a personal QR's link -- `https://myotherapp.in/p/<code>`
/// -- the only thing the widget may draw as a code.
bool isProfileQrLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || !uri.isScheme('https')) return false;
  if (uri.host.toLowerCase() != Uri.parse(AppConfig.publicSiteUrl).host) {
    return false;
  }
  return readScannedCode(link.trim()) is PersonalCode;
}

/// The longest name kept: the widget shows two lines at most.
const _nameLimit = 80;

/// [name] on one line, its spaces collapsed, at most [limit] long; null
/// when there is none.
String? _shown(String? name, int limit) {
  var shown = name?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (shown == null || shown.isEmpty) return null;
  if (shown.length > limit) shown = shown.substring(0, limit).trimRight();
  return shown;
}

/// How many people "Recently met" shows: the large widget's four rows.
const recentlyMetLimit = 4;

/// How many colours the initials' circles come in (the app's teal, pale
/// yellow, ink and soft grey; the widgets hold the shades for each theme).
const recentlyMetColours = 4;

/// The widget key a person's photo is kept under ([RecentlyMetPerson.id]):
/// home_widget stores the file's path under it.
String widgetPhotoKey(int id) => 'networking_photo_$id';

/// One person on the large widget's "Recently met".
class RecentlyMetPerson {
  const RecentlyMetPerson({
    required this.id,
    required this.name,
    required this.initials,
    required this.colour,
    this.event,
    this.picture,
  });

  /// [person] as the widget shows them: their name, its initials, a colour
  /// that stays theirs, and the event they were last met at.
  factory RecentlyMetPerson.of(NetworkPerson person) {
    final name = _shown(person.person.fullName, _nameLimit) ?? 'Someone';
    final events = person.events;
    return RecentlyMetPerson(
      id: person.id,
      name: name,
      initials: initialsOf(name),
      colour: (person.person.userId ?? person.id).abs() % recentlyMetColours,
      event: events.isEmpty ? null : _shown(events.first.name, _nameLimit),
      picture: person.person.picture,
    );
  }

  /// Their entry in the network: `/network/{id}`, their page in the app.
  final int id;
  final String name;
  final String initials;

  /// Which of the [recentlyMetColours] their circle is: from their account,
  /// so it is the same on every draw.
  final int colour;

  /// The event they were last met at, if any.
  final String? event;

  /// Their picture's address, to make the photo from. Never written to the
  /// widget's storage: it is a link that expires, and the widget has no use
  /// for it.
  final String? picture;

  /// What a tap opens: their page in the app (signing in first).
  String get link => siteLink(networkPersonRoute(id));

  /// The JSON the widget reads; [photo] when their photo is kept.
  Map<String, Object?> toJson({String? photo}) => {
        'name': name,
        'initials': initials,
        'colour': colour,
        if (event != null) 'event': event,
        'link': link,
        if (photo != null) 'photo': photo,
      };
}

/// "Recently met": the people last met first, and how many on the page the
/// app read have no note yet.
class RecentlyMet {
  const RecentlyMet({this.people = const [], this.withoutNote = 0});

  /// From [page], the first page of the network last met first
  /// (`recentlyMetQuery`): its first [recentlyMetLimit] people, and how many
  /// of the page have no note. A network larger than the page counts the
  /// people on it -- those met most recently, the ones a note is still
  /// easy to write for.
  factory RecentlyMet.from(NetworkList page) => RecentlyMet(
        people: [
          for (final person in page.items.take(recentlyMetLimit))
            RecentlyMetPerson.of(person),
        ],
        withoutNote: page.items.where((p) => p.note == null).length,
      );

  final List<RecentlyMetPerson> people;
  final int withoutNote;
}

class NetworkingSnapshot {
  const NetworkingSnapshot._(
    this.state, {
    this.name,
    this.profileLink,
    this.networkCount,
    this.recentlyMet,
  });

  /// Nobody signed in: nothing about anyone.
  static const signedOut = NetworkingSnapshot._(NetworkingState.signedOut);

  /// What the widget shows for what the app knows. Signed out, nothing.
  /// Signed in: [qrLink] (the `url` of `GET /me/qr`) when it is a personal
  /// QR's link -- anything else is left out, and the widget offers My QR --
  /// the person's [name], [networkCount] and [recentlyMet], each when
  /// known.
  factory NetworkingSnapshot.from({
    required bool signedIn,
    String? qrLink,
    String? name,
    int? networkCount,
    RecentlyMet? recentlyMet,
  }) {
    if (!signedIn) return signedOut;
    final link =
        qrLink != null && isProfileQrLink(qrLink) ? qrLink.trim() : null;
    return NetworkingSnapshot._(
      link == null ? NetworkingState.noQr : NetworkingState.ready,
      name: _shown(name, _nameLimit),
      profileLink: link,
      networkCount:
          networkCount != null && networkCount >= 0 ? networkCount : null,
      recentlyMet: recentlyMet,
    );
  }

  final NetworkingState state;

  /// The person's name, as on My QR.
  final String? name;

  /// What the QR encodes: their public profile link from `GET /me/qr`.
  final String? profileLink;

  /// How many people are in their network.
  final int? networkCount;

  /// The people they met most recently; null until the app has read them.
  final RecentlyMet? recentlyMet;

  /// The JSON the widgets read. Version 1; a widget that finds a version it
  /// doesn't know shows the signed-out face, which a launch of the app
  /// rewrites. [photos] names the kept photo of each person who has one, by
  /// [RecentlyMetPerson.id].
  Map<String, Object?> toJson({Map<int, String> photos = const {}}) => {
        'v': 1,
        'state': state.wire,
        if (name != null) 'name': name,
        if (profileLink != null) 'profile_link': profileLink,
        if (networkCount != null) 'network': networkCount,
        if (recentlyMet case final met?) ...{
          'met': [
            for (final person in met.people)
              person.toJson(photo: photos[person.id]),
          ],
          'no_note': met.withoutNote,
        },
        'links': networkingLinks,
      };
}
