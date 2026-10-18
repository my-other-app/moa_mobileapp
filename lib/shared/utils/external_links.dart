import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/shared/utils/share_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where people write to us. A team inbox, not anyone's personal number.
const supportEmail = 'support@myotherapp.in';

/// The policies the stores link to, kept on the public site so there is one
/// copy to update rather than one in every app build.
final privacyPolicyUri = Uri.parse('$publicSiteUrl/privacy');
final termsUri = Uri.parse('$publicSiteUrl/terms');
final websiteUri = Uri.parse(publicSiteUrl);
final supportEmailUri = Uri(
  scheme: 'mailto',
  path: supportEmail,
  query: 'subject=MyOtherApp%20support',
);

/// Opens a link outside the app -- the browser, or the mail app for a
/// `mailto:` -- and answers whether anything opened.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// The app's [LinkLauncher]. A provider so a test can see what was opened
/// without a platform channel.
final linkLauncherProvider = Provider<LinkLauncher>((ref) {
  return (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No app for the scheme (a simulator has no mail app) throws on some
      // platforms rather than answering false.
      return false;
    }
  };
});
