import 'package:finnet/common/models/events/cohost_model.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/shared/utils/image_url.dart';

// The event page as the website shows it: `GET /discover/events/{ref}`
// (the event, its club, speakers, team, and what else is on), read without
// trusting any field to be there. The same people also come from
// `/events/info` (speakers only), in a slightly different shape; both are
// read into the one [EventPerson].
//
// The website's reading of the same answer is `parseEventPage` in
// moa_eventwebsite `src/api/parse.js`; the choices here follow it: a
// capacity of 0 is "no limit", a point at 0,0 is "no point", and the
// events in the rails never include this one.

/// Where an event stands, as `/discover/events` says it.
enum EventPhase { upcoming, closingSoon, full, live, ended }

/// [EventPhase] from the API's `status`; null for anything else.
EventPhase? eventPhaseFrom(Object? value) => switch (jsonString(value)) {
      'upcoming' => EventPhase.upcoming,
      'closing_soon' => EventPhase.closingSoon,
      'full' => EventPhase.full,
      'live' => EventPhase.live,
      'ended' => EventPhase.ended,
      _ => null,
    };

/// A number greater than nought, or null: a fee, prize or capacity of 0
/// means "not set", never "0".
double? _positive(Object? value) {
  final n = jsonDouble(value);
  return n != null && n.isFinite && n > 0 ? n : null;
}

/// A count: a whole number, never below nought.
int _count(Object? value) {
  final n = jsonInt(value) ?? 0;
  return n < 0 ? 0 : n;
}

/// Trimmed text, or null when there is none.
String? _text(Object? value) {
  final s = jsonString(value)?.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  return s == null || s.isEmpty ? null : s;
}

/// A link a person can be sent to: http or https, with a host. A bare
/// "linkedin.com/in/asha" is read as https. Anything else (javascript:,
/// mailto:, words) is null.
Uri? safeWebLink(Object? value) {
  final raw = _text(value);
  if (raw == null || raw.contains(RegExp(r'\s'))) return null;
  final hasScheme = RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false);
  final uri = Uri.tryParse(hasScheme.hasMatch(raw) ? raw : 'https://$raw');
  if (uri == null) return null;
  if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
  if (!uri.host.contains('.')) return null;
  return uri;
}

/// What a person's link is to.
enum PersonLinkKind { linkedin, instagram, x, youtube, website }

/// The kind of site [uri] is on.
PersonLinkKind personLinkKindOf(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  bool on(String domain) => host == domain || host.endsWith('.$domain');
  if (on('linkedin.com')) return PersonLinkKind.linkedin;
  if (on('instagram.com')) return PersonLinkKind.instagram;
  if (on('x.com') || on('twitter.com')) return PersonLinkKind.x;
  if (on('youtube.com') || on('youtu.be')) return PersonLinkKind.youtube;
  return PersonLinkKind.website;
}

/// One of a person's links.
class PersonLink {
  final PersonLinkKind kind;
  final Uri uri;

  const PersonLink(this.kind, this.uri);

  /// "LinkedIn", "Instagram", "X", "YouTube", "Website".
  String get label => switch (kind) {
        PersonLinkKind.linkedin => 'LinkedIn',
        PersonLinkKind.instagram => 'Instagram',
        PersonLinkKind.x => 'X',
        PersonLinkKind.youtube => 'YouTube',
        PersonLinkKind.website => 'Website',
      };

  @override
  bool operator ==(Object other) =>
      other is PersonLink && other.kind == kind && other.uri == uri;

  @override
  int get hashCode => Object.hash(kind, uri);
}

/// Someone on the event's page: a speaker, an organiser, or one of the
/// hosting club's team.
class EventPerson {
  final int? id;
  final String name;

  /// A speaker's designation, or a team member's role.
  final String? role;

  /// Their photo's URL, or null for their initials.
  final String? photo;

  /// A speaker's bio; team members have none.
  final String? bio;
  final List<PersonLink> links;

  const EventPerson({
    this.id,
    required this.name,
    this.role,
    this.photo,
    this.bio,
    this.links = const [],
  });

  /// "Ananya Iyer" -> "AI"; "?" without a name.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  /// Whether there is more to show than the row does: a bio or a link.
  bool get hasMore => (bio?.isNotEmpty ?? false) || links.isNotEmpty;

  /// A speaker, from `/discover/events/{ref}` (`photo` a URL) or from
  /// `/events/info` (`photo` the S3 sizes). Null without a name.
  static EventPerson? speakerFromJson(Map<String, dynamic> json) {
    final name = _text(json['name']);
    if (name == null) return null;
    final link = safeWebLink(json['link']);
    return EventPerson(
      id: jsonInt(json['id']),
      name: name,
      role: _text(json['designation']),
      photo: imageUrlFrom(json['photo'],
          prefer: const ['medium', 'large', 'thumbnail', 'original']),
      bio: _text(json['bio']),
      links: [if (link != null) PersonLink(personLinkKindOf(link), link)],
    );
  }

  /// One of the team (`/discover/events/{ref}` `team`): their role, and
  /// their Instagram, LinkedIn, X and website. Null without a name.
  static EventPerson? teamMemberFromJson(Map<String, dynamic> json) {
    final name = _text(json['name']);
    if (name == null) return null;
    final links = jsonObject(json['links']) ?? const <String, dynamic>{};
    return EventPerson(
      name: name,
      role: _text(json['role']),
      photo: imageUrlFrom(json['photo'],
          prefer: const ['medium', 'large', 'thumbnail', 'original']),
      links: [
        for (final (key, kind) in const [
          ('instagram', PersonLinkKind.instagram),
          ('linkedin', PersonLinkKind.linkedin),
          ('x', PersonLinkKind.x),
          ('website', PersonLinkKind.website),
        ])
          if (safeWebLink(links[key]) case final uri?) PersonLink(kind, uri),
      ],
    );
  }

  /// Every speaker in [value] (a list), skipping any without a name.
  static List<EventPerson> speakersFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (speakerFromJson(json) case final person?) person,
      ];

  /// Every team member in [value] (a list), skipping any without a name.
  static List<EventPerson> teamFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (teamMemberFromJson(json) case final person?) person,
      ];
}

/// Whether an [EventBacker] sponsors the event or partners it.
enum BackerKind { sponsor, partner }

/// One of the event's own sponsors or partners (`/discover/events/{ref}`
/// `sponsors` and `partners`; the API's docs/EVENT_PARTNERS.md): a name, a
/// label ("Title sponsor"), an https link and a logo, shown whole in a
/// square tile. The website reads the same lists (`parseBacker` in
/// moa_eventwebsite `src/api/parse.js`).
class EventBacker {
  final int? id;
  final BackerKind kind;
  final String name;

  /// "Title sponsor", "Venue partner"; null when the club set none.
  final String? label;

  /// Where a tap goes: https only, else null.
  final Uri? link;

  /// The logo's URL, or null for the initials.
  final String? logo;

  const EventBacker({
    this.id,
    required this.kind,
    required this.name,
    this.label,
    this.link,
    this.logo,
  });

  /// "Kinetic Labs" -> "KL"; "?" without a name.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  /// One row of [kind]; null without a name. A link that is not https is
  /// dropped, as the website drops it.
  static EventBacker? fromJson(Map<String, dynamic> json, BackerKind kind) {
    final name = _text(json['name']);
    if (name == null) return null;
    final link = safeWebLink(json['link']);
    return EventBacker(
      id: jsonInt(json['id']),
      kind: kind,
      name: name,
      label: _text(json['label']),
      link: link != null && link.isScheme('https') ? link : null,
      logo: imageUrlFrom(json['logo'],
          prefer: const ['medium', 'large', 'original', 'thumbnail']),
    );
  }

  /// Every row in [value] (a list), skipping any without a name. Absent
  /// (an older API): none.
  static List<EventBacker> listFrom(Object? value, BackerKind kind) => [
        for (final json in jsonObjects(value))
          if (fromJson(json, kind) case final backer?) backer,
      ];
}

/// Who to ask about the event.
class EventContact {
  final String? name;
  final String? email;
  final String? phone;

  const EventContact({this.name, this.email, this.phone});

  static const none = EventContact();

  /// Nothing to reach them by: no email and no phone.
  bool get isEmpty => email == null && phone == null;

  factory EventContact.fromJson(Map<String, dynamic> json) => EventContact(
        name: _text(json['name']),
        email: _text(json['email']),
        phone: _text(json['phone']),
      );

  /// [email] and [phone] where this has none.
  EventContact or(EventContact other) => EventContact(
        name: name ?? other.name,
        email: email ?? other.email,
        phone: phone ?? other.phone,
      );

  /// The number to dial: digits and a leading +; null without one.
  String? get dialable {
    final digits = phone?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
    return digits.isEmpty ? null : digits;
  }
}

/// Another event, as a card in "More from this club" or "Similar events".
class EventSummary {
  final int id;
  final String slug;
  final String name;

  /// A URL, or the S3 sizes.
  final Object? poster;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? locationName;
  final bool isOnline;
  final bool hasFee;
  final double? fee;
  final int? categoryId;
  final String? categoryName;
  final String? clubName;
  final int going;
  final EventPhase? phase;

  const EventSummary({
    required this.id,
    this.slug = '',
    required this.name,
    this.poster,
    this.startsAt,
    this.endsAt,
    this.locationName,
    this.isOnline = false,
    this.hasFee = false,
    this.fee,
    this.categoryId,
    this.categoryName,
    this.clubName,
    this.going = 0,
    this.phase,
  });

  /// One card from `/discover/*` (`EventCard`); null without an id.
  static EventSummary? fromJson(Map<String, dynamic> json) {
    final id = jsonInt(json['id']);
    if (id == null) return null;
    final category = jsonObject(json['category']);
    final club = jsonObject(json['club']);
    return EventSummary(
      id: id,
      slug: _text(json['slug']) ?? '',
      name: _text(json['name']) ?? 'Untitled event',
      poster: json['poster'],
      startsAt: jsonDate(json['starts_at'])?.toLocal(),
      endsAt: jsonDate(json['ends_at'])?.toLocal(),
      locationName: _text(json['location_name']),
      isOnline: jsonBool(json['is_online']) ?? false,
      hasFee: jsonBool(json['has_fee']) ?? false,
      fee: _positive(json['fee']),
      categoryId: jsonInt(category?['id']),
      categoryName: _text(category?['name']),
      clubName: _text(club?['name']),
      going: _count(json['going']),
      phase: eventPhaseFrom(json['status']),
    );
  }

  /// The app's route to the event: by id, which every version of the
  /// router reads.
  String get route => '/events/$id';
}

/// The hosting club, as the event page shows it.
class EventPageClub {
  final int? id;
  final String name;
  final String slug;
  final String? logo;
  final String? tagline;
  final int followers;

  const EventPageClub({
    this.id,
    required this.name,
    this.slug = '',
    this.logo,
    this.tagline,
    this.followers = 0,
  });

  static EventPageClub? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    final name = _text(json['name']);
    final id = jsonInt(json['id']);
    if (name == null && id == null) return null;
    return EventPageClub(
      id: id,
      name: name ?? 'A club',
      slug: _text(json['slug']) ?? '',
      logo: imageUrlFrom(json['logo']),
      tagline: _text(json['tagline']),
      followers: _count(json['followers']),
    );
  }
}

/// Where the team section's people come from: the event's own organisers,
/// or (when the event names none) the hosting club's team.
enum TeamSource { event, club }

/// `GET /discover/events/{ref}`: what the website's event page shows,
/// beyond what `/events/info` has. Public events only -- the API answers
/// 404 for a draft, a deleted event or an unverified club's, and then the
/// page shows what `/events/info` has, as it always did.
class EventPageDetails {
  final int id;
  final String slug;
  final String name;

  /// The event's address on the website, as the API gives it.
  final String? url;
  final EventPhase? phase;

  /// The club called it off (`status: "cancelled"`, with `cancellation`);
  /// null otherwise. [phase] is then null: no list shows it.
  final EventCancellation? cancellation;

  /// The club confirms each registration (`requires_approval`; false when
  /// not said): the register button asks for a place.
  final bool requiresApproval;

  /// The club has its "High demand" label on (`high_demand`; false when
  /// not said). No number comes with it.
  final bool highDemand;

  /// Whether a new registration would be taken right now.
  final bool registrationOpen;
  final DateTime? regOpensAt;
  final DateTime? regClosesAt;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Places, when the event has a limit; null when it has none.
  final int? capacity;
  final int going;

  /// Places still free, when the event has a limit and the API says.
  final int? seatsLeftReported;
  final double? lat;
  final double? lng;
  final String? locationName;
  final String? locationLink;
  final bool isOnline;
  final bool hasFee;
  final double? fee;
  final String? guidelines;
  final EventContact contact;
  final EventPageClub? club;

  /// The clubs co-hosting the event with [club] (`cohosts`, beside it); empty
  /// when it has none, and from a server older than co-hosting.
  final List<EventCohost> cohosts;
  final List<EventPerson> speakers;
  final List<EventPerson> team;

  /// Null when there is no team to show.
  final TeamSource? teamSource;

  /// The event's own sponsors, then its partners, each in the club's
  /// order; empty from an API that has none (the sections then hide).
  final List<EventBacker> sponsors;
  final List<EventBacker> partners;
  final List<EventSummary> moreFromClub;
  final List<EventSummary> similar;

  const EventPageDetails({
    required this.id,
    this.slug = '',
    this.name = '',
    this.url,
    this.phase,
    this.cancellation,
    this.requiresApproval = false,
    this.highDemand = false,
    this.registrationOpen = false,
    this.regOpensAt,
    this.regClosesAt,
    this.startsAt,
    this.endsAt,
    this.capacity,
    this.going = 0,
    this.seatsLeftReported,
    this.lat,
    this.lng,
    this.locationName,
    this.locationLink,
    this.isOnline = false,
    this.hasFee = false,
    this.fee,
    this.guidelines,
    this.contact = EventContact.none,
    this.club,
    this.cohosts = const [],
    this.speakers = const [],
    this.team = const [],
    this.teamSource,
    this.sponsors = const [],
    this.partners = const [],
    this.moreFromClub = const [],
    this.similar = const [],
  });

  /// Places still free: what the API said, or the capacity less those
  /// going; null when the event has no limit.
  int? get seatsLeft {
    final cap = capacity;
    if (cap == null) return null;
    final left = seatsLeftReported ?? cap - going;
    return left < 0 ? 0 : left;
  }

  /// Whether the venue has a point on the map.
  bool get hasPoint => lat != null && lng != null;

  /// The page, or null when [data] isn't one (no event, or no id).
  static EventPageDetails? fromJson(Object? data) {
    final root = jsonObject(data);
    final event = jsonObject(root?['event']);
    final id = jsonInt(event?['id']);
    if (root == null || event == null || id == null) return null;

    final lat = jsonDouble(event['lat']);
    final lng = jsonDouble(event['lng']);
    // 0,0 is the sea off Ghana: a venue nobody picked.
    final placed = lat != null &&
        lng != null &&
        !(lat == 0 && lng == 0) &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;
    final capacity = _positive(event['capacity'])?.floor();
    final seats = jsonDouble(event['seats_left']);
    final team = EventPerson.teamFrom(root['team']);
    final teamSource = switch (jsonString(root['team_source'])) {
      'event' => TeamSource.event,
      'club' => TeamSource.club,
      _ => null,
    };
    List<EventSummary> others(Object? rows) => [
          for (final json in jsonObjects(rows))
            if (EventSummary.fromJson(json) case final e? when e.id != id) e,
        ];

    return EventPageDetails(
      id: id,
      slug: _text(event['slug']) ?? '',
      name: _text(event['name']) ?? '',
      url: _text(event['url']),
      phase: eventPhaseFrom(event['status']),
      cancellation: EventCancellation.of(event),
      // On the event, or on its `ticketing` (the event's, or the page's).
      requiresApproval: jsonBool(event['requires_approval']) ??
          jsonBool(jsonObject(event['ticketing'])?['requires_approval']) ??
          jsonBool(jsonObject(root['ticketing'])?['requires_approval']) ??
          false,
      highDemand: jsonBool(event['high_demand']) ?? false,
      registrationOpen: jsonBool(event['registration_open']) ?? false,
      regOpensAt: jsonDate(event['reg_opens_at'])?.toLocal(),
      regClosesAt: jsonDate(event['reg_closes_at'])?.toLocal(),
      startsAt: jsonDate(event['starts_at'])?.toLocal(),
      endsAt: jsonDate(event['ends_at'])?.toLocal(),
      capacity: capacity,
      going: _count(event['going']),
      seatsLeftReported: capacity != null && seats != null && seats.isFinite
          ? (seats < 0 ? 0 : seats.floor())
          : null,
      lat: placed ? lat : null,
      lng: placed ? lng : null,
      locationName: _text(event['location_name']),
      locationLink: _text(event['location_link']),
      isOnline: jsonBool(event['is_online']) ?? false,
      hasFee: jsonBool(event['has_fee']) ?? false,
      fee: _positive(event['fee']),
      guidelines: _text(event['guidelines']),
      contact: EventContact.fromJson(
          jsonObject(event['contact']) ?? const <String, dynamic>{}),
      club: EventPageClub.fromJson(root['club']),
      // Beside the club; read from the event too, should it come there.
      cohosts: EventCohost.listFrom(root['cohosts'] ?? event['cohosts'],
          hostId: jsonInt(jsonObject(root['club'])?['id'])),
      speakers: EventPerson.speakersFrom(root['speakers']),
      team: teamSource == null ? const [] : team,
      teamSource: team.isEmpty ? null : teamSource,
      sponsors: EventBacker.listFrom(root['sponsors'], BackerKind.sponsor),
      partners: EventBacker.listFrom(root['partners'], BackerKind.partner),
      moreFromClub: others(root['more_from_club']),
      similar: others(root['similar']),
    );
  }
}
