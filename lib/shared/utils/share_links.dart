import 'package:finnet/core/config/app_config.dart';

// Links to the public site (AppConfig.publicSiteUrl). An event's page is
// `eventShareUrl` in features/events/presentation/utils/event_feed.dart.

/// The public page for a club: `https://myotherapp.in/clubs/{slug}`.
///
/// The slug is what the site routes on. A club without one (older rows) falls
/// back to its id; with neither there is nothing to link to and this answers
/// null, so the caller can leave the share button out.
String? clubShareUrl({String? slug, int? id}) {
  final s = slug?.trim() ?? '';
  if (s.isNotEmpty) {
    return '${AppConfig.publicSiteUrl}/clubs/${Uri.encodeComponent(s)}';
  }
  if (id != null && id > 0) return '${AppConfig.publicSiteUrl}/clubs/$id';
  return null;
}
