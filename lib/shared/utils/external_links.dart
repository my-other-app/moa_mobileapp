import 'package:finnet/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where people write to us. A team inbox, not anyone's personal number.
const supportEmail = 'support@myotherapp.in';

/// The policies the stores link to, kept on the public site so there is one
/// copy to update rather than one in every app build.
final privacyPolicyUri = Uri.parse('${AppConfig.publicSiteUrl}/privacy');
final termsUri = Uri.parse('${AppConfig.publicSiteUrl}/terms');
final websiteUri = Uri.parse(AppConfig.publicSiteUrl);
final supportEmailUri = Uri(
  scheme: 'mailto',
  path: supportEmail,
  query: 'subject=MyOtherApp%20support',
);

/// Opens a link -- a page of our site inside the app, anything else in the
/// browser or the app for its scheme (`mailto:`) -- and answers whether
/// anything opened.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// How a link is handed to the platform: url_launcher's `launchUrl`.
typedef PlatformLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

Future<bool> _launch(Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);

/// The live room of [eventId]: the website's page, so polls, Q&A and the
/// quiz are the same on every phone. The quiz is joined from here with the
/// code on the screen; the site's `/play/{id}` only works for someone who
/// has already joined, and shows anyone else a link back to this room.
Uri liveRoomUri(Object eventId) =>
    Uri.parse('${AppConfig.publicSiteUrl}/$eventId/live');

/// Whether [uri] is a page of our own site (myotherapp.in or a subdomain).
bool isOwnSite(Uri uri) {
  final site = websiteUri.host;
  final host = uri.host.toLowerCase();
  return (uri.isScheme('https') || uri.isScheme('http')) &&
      (host == site || host.endsWith('.$site'));
}

/// Opens [uri] inside the app -- SFSafariViewController on iOS, a Custom
/// Tab on Android, so the person stays in the app and Back returns to it --
/// and in the browser when that cannot be done (no in-app browser, or the
/// platform refused). Answers whether anything opened; never throws.
Future<bool> openInAppThenBrowser(
  Uri uri, {
  PlatformLauncher launch = _launch,
}) async {
  try {
    if (await launch(uri, LaunchMode.inAppBrowserView)) return true;
  } catch (_) {
    // No in-app browser here; the browser is next.
  }
  try {
    return await launch(uri, LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Opens [uri] outside the app: the browser, or the app for its scheme.
Future<bool> openExternally(
  Uri uri, {
  PlatformLauncher launch = _launch,
}) async {
  try {
    return await launch(uri, LaunchMode.externalApplication);
  } catch (_) {
    // No app for the scheme (a simulator has no mail app) throws on some
    // platforms rather than answering false.
    return false;
  }
}

/// The app's [LinkLauncher]: our own site's pages (the policies, a
/// certificate, the live room) open inside the app, everything else
/// outside it. A provider so a test can see what was opened without a
/// platform channel.
final linkLauncherProvider = Provider<LinkLauncher>((ref) {
  return (uri) =>
      isOwnSite(uri) ? openInAppThenBrowser(uri) : openExternally(uri);
});
