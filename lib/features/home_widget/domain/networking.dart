import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart' show siteLink;
import 'package:finnet/features/network/domain/network_links.dart';

/// What the "Networking" home-screen widget shows (docs/HOME_WIDGETS.md):
/// the person's QR code to share, their name, and a quick way to scan
/// someone and to their network.
///
/// It is written to storage the phone's lock screen and anyone holding the
/// phone can read, so it holds only what the widget shows and where a tap
/// goes: the version, the state, the person's name, the public profile
/// link their QR encodes (from `GET /me/qr`), how many people are in their
/// network, and the taps' links. Never a ticket, a token, an email or a
/// phone number.

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

class NetworkingSnapshot {
  const NetworkingSnapshot._(
    this.state, {
    this.name,
    this.profileLink,
    this.networkCount,
  });

  /// Nobody signed in: nothing about anyone.
  static const signedOut = NetworkingSnapshot._(NetworkingState.signedOut);

  /// What the widget shows for what the app knows. Signed out, nothing.
  /// Signed in: [qrLink] (the `url` of `GET /me/qr`) when it is a personal
  /// QR's link -- anything else is left out, and the widget offers My QR --
  /// the person's [name], and [networkCount], each when known.
  factory NetworkingSnapshot.from({
    required bool signedIn,
    String? qrLink,
    String? name,
    int? networkCount,
  }) {
    if (!signedIn) return signedOut;
    final link =
        qrLink != null && isProfileQrLink(qrLink) ? qrLink.trim() : null;
    var shown = name?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (shown != null && shown.isEmpty) shown = null;
    if (shown != null && shown.length > _nameLimit) {
      shown = shown.substring(0, _nameLimit);
    }
    return NetworkingSnapshot._(
      link == null ? NetworkingState.noQr : NetworkingState.ready,
      name: shown,
      profileLink: link,
      networkCount:
          networkCount != null && networkCount >= 0 ? networkCount : null,
    );
  }

  final NetworkingState state;

  /// The person's name, as on My QR.
  final String? name;

  /// What the QR encodes: their public profile link from `GET /me/qr`.
  final String? profileLink;

  /// How many people are in their network.
  final int? networkCount;

  /// The JSON the widgets read. Version 1; a widget that finds a version it
  /// doesn't know shows the signed-out face, which a launch of the app
  /// rewrites.
  Map<String, Object?> toJson() => {
        'v': 1,
        'state': state.wire,
        if (name != null) 'name': name,
        if (profileLink != null) 'profile_link': profileLink,
        if (networkCount != null) 'network': networkCount,
        'links': networkingLinks,
      };
}
