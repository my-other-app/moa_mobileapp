import 'package:finnet/core/config/app_config.dart';

/// The website's addresses, and the app's screen for each.
///
/// The app's routes use the website's own paths wherever they can, so a
/// universal link (iOS) or an App Link (Android) for
/// `https://myotherapp.in/events/hack-night-04` opens the route
/// `/events/hack-night-04` as it is. The site claims these for the apps in
/// `/.well-known/` (moa_eventwebsite, `src/seo/appLinks.js`):
///
/// | Website                        | App                                  |
/// | ------------------------------ | ------------------------------------ |
/// | `/events/{slug or id}`         | the event's page                     |
/// | `/events/{ref}/live`           | the event, with its live room open   |
/// | `/events/{ref}/register`       | the event's page (Register is there) |
/// | `/events/{ref}/compete`        | the event's page                     |
/// | `/clubs/{slug or id}`          | the club                             |
/// | `/threads/{id}`                | the post                             |
/// | `/tickets/{id}`                | the ticket (its QR works offline)    |
/// | `/certificates/{id}`           | the certificate                      |
/// | `/topics/{slug}`               | the topic                            |
///
/// iPhone leaves the live room and the competition pages in the browser
/// (the site's file excludes them); Android's intent filters cannot leave a
/// path out, so the app handles those too.
///
/// [webLocation] also reads the few addresses the site has that are not
/// claimed (the old `/{id}` event links, the directories, `/me/...`), for a
/// link that reaches the app some other way: a push's `url`.

/// The hosts that are this site: the apex, and the two that redirect to it.
bool isSiteHost(String host) {
  final site = Uri.parse(AppConfig.publicSiteUrl).host;
  final h = host.toLowerCase();
  return h == site || h == 'www.$site' || h == 'events.$site';
}

/// The app's location for [uri] -- a link to the website, or just its path
/// -- or null when the app has no screen for it (it is opened in the
/// browser instead). The query is kept, so a club's `?ref=` and the like
/// reach the screen.
String? webLocation(Uri uri) {
  if (uri.hasScheme) {
    if (!(uri.isScheme('https') || uri.isScheme('http'))) return null;
    if (!isSiteHost(uri.host)) return null;
  } else if (uri.hasAuthority) {
    return null;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final query = uri.queryParameters;

  String at(String path, [Map<String, String> extra = const {}]) {
    final all = {...query, ...extra};
    return Uri(path: path, queryParameters: all.isEmpty ? null : all)
        .toString();
  }

  String one(String segment) => Uri.encodeComponent(segment);

  if (segments.isEmpty) return at('/');
  final head = segments.first.toLowerCase();
  final rest = segments.skip(1).toList();

  // Feeds and files are never pages.
  if (segments.last.contains('.')) return null;

  switch (head) {
    case 'events':
      if (rest.isEmpty) return at('/events/explore');
      final ref = one(rest.first);
      if (rest.length == 1) return at('/events/$ref');
      if (rest.length == 2) {
        switch (rest[1].toLowerCase()) {
          case 'live':
            return at('/events/$ref', const {'live': 'room'});
          // Registering starts from the event's page, which has the form's
          // questions; the page's Register asks for sign-in when needed.
          case 'register':
          case 'compete':
            return at('/events/$ref');
        }
      }
      return null;
    case 'clubs':
      if (rest.isEmpty) return at('/clubs/explore');
      return rest.length == 1 ? at('/clubs/${one(rest.first)}') : null;
    case 'threads':
    case 'tickets':
    case 'certificates':
    case 'topics':
      return rest.length == 1 ? at('/$head/${one(rest.first)}') : null;
    case 'me':
      if (rest.length != 1) return null;
      switch (rest.first.toLowerCase()) {
        case 'tickets':
          return at('/events');
        case 'following':
          return at('/clubs');
      }
      return null;
  }

  // The old event addresses: /{id} and /{id}/live (posters, QR codes,
  // older emails). Only an id: a word there is one of the site's pages.
  if (int.tryParse(head) != null) {
    if (rest.isEmpty) return at('/events/$head');
    if (rest.length == 1 && rest.first.toLowerCase() == 'live') {
      return at('/events/$head', const {'live': 'room'});
    }
  }
  return null;
}

/// The website's page for an app [location] (a path and query): what "Open
/// in browser" opens when the app cannot show it.
Uri websiteUriFor(String location) {
  final uri = Uri.parse(location);
  return Uri.parse(AppConfig.publicSiteUrl).replace(
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
  );
}
