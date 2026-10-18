/// The public site's address. Club, event and policy pages all live under it.
const publicSiteUrl = 'https://myotherapp.in';

/// The public page for a club: `https://myotherapp.in/clubs/{slug}`.
///
/// The slug is what the site routes on. A club without one (older rows) falls
/// back to its id; with neither there is nothing to link to and this answers
/// null, so the caller can leave the share button out.
String? clubShareUrl({String? slug, int? id}) {
  final s = slug?.trim() ?? '';
  if (s.isNotEmpty) return '$publicSiteUrl/clubs/${Uri.encodeComponent(s)}';
  if (id != null && id > 0) return '$publicSiteUrl/clubs/$id';
  return null;
}
