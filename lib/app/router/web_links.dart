import 'package:finnet/core/config/app_config.dart';

/// The website's addresses, and the app's screen for each.
///
/// A universal link (iOS) or an App Link (Android) reaches the router as the
/// whole URL, `https://myotherapp.in/events/hack-night-04`; the router's
/// redirect hands it to [webLocation], and goes where that says. The site
/// claims these for the apps in `/.well-known/` (moa_eventwebsite,
/// `src/seo/appLinks.js`):
///
/// | Website                          | App                                   |
/// | -------------------------------- | ------------------------------------- |
/// | `/events?…`                      | `/discover/events?…` (Find events)    |
/// | `/events/in`, `/events/in/{city}`| `/discover/events?…` (Find events)    |
/// | `/events/{slug or id}`           | the event's page                      |
/// | `/events/{ref}/live`             | the live room, in the app             |
/// | `/events/{ref}/register`         | registration                          |
/// | `/events/{ref}/compete`          | the competition                       |
/// | `/clubs?…`                       | `/discover/clubs?…` (the directory)   |
/// | `/clubs/in`, `/clubs/in/{city}`  | `/discover/clubs?…` (the directory)   |
/// | `/clubs/{slug or id}`            | the club                              |
/// | `/threads`                       | `/discover/threads` (every club's)    |
/// | `/threads/{id}`                  | the post                              |
/// | `/tickets/{id}`                  | the ticket (its QR works offline)     |
/// | `/certificates/{id}`             | the certificate                       |
/// | `/topics`, `/topics/{slug}`      | the topics, a topic                   |
/// | `/feedback/{event}/{reg}?k=`     | the feedback survey                   |
/// | `/play/{event}`                  | the quiz, to join (its QR)            |
///
/// The app's own `/events` and `/clubs` are the person's events and clubs
/// (the tabs); the website's are the directories, which is why a link is
/// read here first rather than matched as it is.
///
/// Both phones open the live room (`/events/*/live`) and the quiz's QR
/// (`/play/*`) in the app: the site's files claim them for iOS, and the
/// Android intent filters (`/events/`, `/play/`) for Android. [webLocation]
/// also reads the addresses the site has that are not claimed (the old
/// `/{id}` event links, `/me/...`), for a link that reaches the app some
/// other way: a push's `url`.

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
      // The directory: Find events, with the site's own filters.
      if (rest.isEmpty) return at('/discover/events');
      // The city pages ("Events in Kochi") are the directory too; read as
      // an event, `/events/in` would open an event called "in".
      if (_isCityPage(rest)) return at('/discover/events');
      final ref = one(rest.first);
      if (rest.length == 1) return at('/events/$ref');
      if (rest.length == 2) {
        switch (rest[1].toLowerCase()) {
          case 'live':
            return at('/events/$ref/live');
          case 'register':
            return at('/events/$ref/register');
          case 'compete':
            return at('/events/$ref/compete');
        }
      }
      return null;
    case 'clubs':
      if (rest.isEmpty || _isCityPage(rest)) return at('/discover/clubs');
      return rest.length == 1 ? at('/clubs/${one(rest.first)}') : null;
    case 'threads':
      if (rest.isEmpty) return at('/discover/threads');
      return rest.length == 1 ? at('/threads/${one(rest.first)}') : null;
    case 'topics':
      if (rest.isEmpty) return at('/topics');
      return rest.length == 1 ? at('/topics/${one(rest.first)}') : null;
    case 'tickets':
    case 'certificates':
      return rest.length == 1 ? at('/$head/${one(rest.first)}') : null;
    case 'play':
      // The website's quiz, joined from its live room.
      return rest.length == 1 && int.tryParse(rest.first) != null
          ? at('/events/${rest.first}/live/quiz')
          : null;
    case 'feedback':
      return rest.length == 2
          ? at('/feedback/${one(rest[0])}/${one(rest[1])}')
          : null;
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
      return at('/events/$head/live');
    }
  }
  return null;
}

/// The site's city pages under `/events` and `/clubs`: `in`, then at most
/// the city's name. No event or club is called "in" (an event's slug ends
/// in its six-character code).
bool _isCityPage(List<String> rest) =>
    rest.first.toLowerCase() == 'in' && rest.length <= 2;

/// Where the router goes for a [uri] it was handed: a link to the website
/// becomes the app's location for it ([webLocation]); a page of the site
/// the app does not have becomes its path, which no route matches, so the
/// friendly page offers it in the browser. Null for anything else -- an
/// address inside the app, or another app's callback -- left as it is.
String? appLocationForLink(Uri uri) {
  if (!uri.hasScheme || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  if (!isSiteHost(uri.host)) return null;
  return webLocation(uri) ??
      Uri(
              path: uri.path.isEmpty ? '/' : uri.path,
              query: uri.hasQuery ? uri.query : null)
          .toString();
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
