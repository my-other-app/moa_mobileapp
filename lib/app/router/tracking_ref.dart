/// A club's tracking link's code, carried from the link that opened the app
/// to the registration or the follow it led to -- as the website carries it
/// (moa_events `src/utils/ref.js`).
///
/// A club makes a link for a poster, a story or a WhatsApp message:
/// `api.myotherapp.in/l/{code}` counts the click and sends the phone on to
/// the club's or the event's page with `?ref={code}` (`&via=l`); a plain
/// page link can carry `?ref=` itself. Either way the app is opened on that
/// address, and the router hands every address it is asked for to
/// [remember]. The code is then sent with
///
///   * a registration: `ref` in `POST /events/registration/{id}/register`,
///   * a follow: `?ref=` on `POST /clubs/follow/{id}`,
///
/// and the server credits the sign-up or the follow to the link -- only a
/// link of that club (and, for an event's link, that event), so sending it
/// with anything else does nothing. Nothing else is kept or reported.
///
/// `sref` is the club website's own code on its event buttons: the weaker
/// claim, kept only when no `ref` is held, so someone who reached the site
/// through one of the club's links keeps that link's credit.
///
/// The website keeps the code for the tab's lifetime; the app keeps it in
/// memory for this run of the app, and at most [keepFor] -- a phone can
/// keep the app alive for days, long after the poster was scanned.
library;

class TrackingRef {
  TrackingRef(
      {DateTime Function()? now, this.keepFor = const Duration(hours: 24)})
      : _now = now ?? DateTime.now;

  /// The app's one: the router writes it, registration and following read it.
  static TrackingRef instance = TrackingRef();

  final DateTime Function() _now;

  /// How long a code is sent after the link that brought it.
  final Duration keepFor;

  /// A tracking link's code, as the server makes them and the website
  /// checks them.
  static final _code = RegExp(r'^[a-z0-9]{4,16}$', caseSensitive: false);

  String? _ref;
  DateTime? _at;

  /// The code to credit now, or null.
  String? get current {
    final at = _at;
    if (_ref == null || at == null) return null;
    if (_now().difference(at) > keepFor) {
      clear();
      return null;
    }
    return _ref;
  }

  /// Keep the code [uri] carries, if it carries one: its `ref`, else its
  /// `sref` when no code is held. A malformed code is ignored.
  void remember(Uri uri) {
    final Map<String, String> query;
    try {
      query = uri.queryParameters;
    } catch (_) {
      return; // A query that does not decode: nothing to keep.
    }
    final ref = query['ref']?.trim();
    if (ref != null && _code.hasMatch(ref)) {
      _keep(ref);
      return;
    }
    final sref = query['sref']?.trim();
    if (sref != null && _code.hasMatch(sref) && current == null) _keep(sref);
  }

  void _keep(String code) {
    _ref = code.toLowerCase();
    _at = _now();
  }

  void clear() {
    _ref = null;
    _at = null;
  }
}
