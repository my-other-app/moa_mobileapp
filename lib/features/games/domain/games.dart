/// The event's two games, as the server's public card for them says
/// (feature-register `games/CONTRACT.md` §3, `GET /games/{event_id}/public`).
///
/// The games run as mobile web pages on our website; the app only offers a
/// way in. Parsing is tolerant: anything that is not the shape below is "no
/// games", never an error.
enum GameKind {
  cards('Hero Cards'),
  hunt('Scavenger Hunt');

  const GameKind(this.defaultName);

  /// What it is called when the organiser has not named it.
  final String defaultName;
}

/// One game that is switched on for the event.
class GameOffer {
  const GameOffer(this.kind, this.name);

  final GameKind kind;

  /// The organiser's name for it, else [GameKind.defaultName].
  final String name;

  /// The button's words.
  String get label => 'Play $name';

  @override
  bool operator ==(Object other) =>
      other is GameOffer && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);
}

class EventGames {
  const EventGames(this.offers, {this.slug, this.canPlay});

  /// Nothing to play.
  static const none = EventGames([]);

  /// The games that are on, cards first.
  final List<GameOffer> offers;

  /// The event's slug: the games' address is `/play/<slug>`, never the id
  /// (`/play/<number>` is the live quiz). Null when the server sent none.
  final String? slug;

  /// `me.can_play`, which the server adds for a signed-in caller; null
  /// when it did not say, and then the buttons are shown.
  final bool? canPlay;

  /// Nothing to show: no game is on, or the server says this person
  /// cannot play.
  bool get isEmpty => offers.isEmpty || canPlay == false;

  /// The server's slug or, failing that, [candidate]; null when neither is
  /// a real slug (empty, or only digits, which is an id).
  String? slugOr(String? candidate) =>
      usableSlug(slug) ?? usableSlug(candidate);

  /// [value] trimmed, unless it is empty or only digits (an id).
  static String? usableSlug(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty || int.tryParse(v) != null ? null : v;
  }

  /// Reads the public card; [json] of any other shape is [none].
  factory EventGames.fromJson(Object? json) {
    if (json is! Map) return none;
    final offers = <GameOffer>[];
    for (final kind in GameKind.values) {
      final offer = _offer(kind, json[kind.name]);
      if (offer != null) offers.add(offer);
    }
    if (offers.isEmpty) return none;
    final event = json['event'];
    final me = json['me'];
    return EventGames(
      offers,
      slug: usableSlug(event is Map && event['slug'] is String
          ? event['slug'] as String
          : null),
      canPlay:
          me is Map && me['can_play'] is bool ? me['can_play'] as bool : null,
    );
  }

  static GameOffer? _offer(GameKind kind, Object? raw) {
    if (raw is! Map || raw['on'] != true) return null;
    final name = raw['name'];
    final trimmed = name is String ? name.trim() : '';
    return GameOffer(kind, trimmed.isEmpty ? kind.defaultName : trimmed);
  }
}

/// A game session for the person: the token the website takes in the
/// address's fragment. It is a credential -- never log it or put it in a
/// report.
class GameSession {
  const GameSession(this.token);

  final String token;

  /// `{token, expires_at}`; null when there is no token to use.
  static GameSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final token = json['token'];
    if (token is! String || token.trim().isEmpty) return null;
    return GameSession(token.trim());
  }
}
