/// A speaker's public page (feature-register `speakers-contract.md`,
/// "Speakers themselves and the public"): `GET /speakers/{slug}`, read
/// without trusting any field to be there.
library;

import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// The push sent to a speaker's followers when they are added to a
/// published event (`speaker_event`, data `{event_id, slug}`): it opens
/// the event.
const speakerEventType = 'speaker_event';

/// The app's (and the website's) address of a speaker's page.
String speakerRoute(String slug) => '/speakers/${Uri.encodeComponent(slug)}';

String? _text(Object? value) {
  final s = jsonString(value)?.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  return s == null || s.isEmpty ? null : s;
}

/// A topic's name: the text itself, or an object's `name`. A bare id has
/// none to show.
String? _topicName(Object? topic) =>
    topic is String ? _text(topic) : _text(jsonObject(topic)?['name']);

int _count(Object? value) {
  final n = jsonInt(value) ?? 0;
  return n < 0 ? 0 : n;
}

/// One of a speaker's talks: an event they spoke (or will speak) at.
class SpeakerTalk {
  const SpeakerTalk({
    required this.eventId,
    required this.eventName,
    this.eventSlug,
    this.date,
    this.clubName,
    this.talkTitle,
    this.poster,
  });

  final int eventId;
  final String? eventSlug;
  final String eventName;
  final DateTime? date;
  final String? clubName;
  final String? talkTitle;
  final String? poster;

  /// The event's page in the app: by slug, else by id.
  String get eventRoute =>
      '/events/${Uri.encodeComponent(eventSlug ?? '$eventId')}';

  static SpeakerTalk? fromJson(Map<String, dynamic> json) {
    final id = jsonInt(json['event_id']) ?? jsonInt(json['id']);
    final name = _text(json['name']) ?? _text(json['event_name']);
    if (id == null || name == null) return null;
    final club = json['club'];
    return SpeakerTalk(
      eventId: id,
      eventSlug: _text(json['slug']),
      eventName: name,
      date: jsonDate(json['date']) ?? jsonDate(json['starts_at']),
      clubName: _text(jsonObject(club)?['name']) ?? _text(club),
      talkTitle: _text(json['talk_title']),
      poster: imageUrlFrom(json['poster'],
          prefer: const ['medium', 'thumbnail', 'large', 'original']),
    );
  }

  static List<SpeakerTalk> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (fromJson(json) case final talk?) talk,
      ];
}

/// A speaker's public page.
class SpeakerProfile {
  const SpeakerProfile({
    required this.slug,
    required this.name,
    this.headline,
    this.bio,
    this.photo,
    this.city,
    this.links = const [],
    this.topics = const [],
    this.claimed = false,
    this.followersCount = 0,
    this.following = false,
    this.upcoming = const [],
    this.past = const [],
  });

  final String slug;
  final String name;
  final String? headline;
  final String? bio;
  final String? photo;
  final String? city;
  final List<PersonLink> links;

  /// The topics' names, where the server names them.
  final List<String> topics;

  /// The speaker has claimed the page as theirs.
  final bool claimed;
  final int followersCount;

  /// The signed-in person follows them.
  final bool following;
  final List<SpeakerTalk> upcoming;
  final List<SpeakerTalk> past;

  /// "Ananya Iyer" -> "AI".
  String get initials => EventPerson(name: name).initials;

  SpeakerProfile copyWith({bool? following, int? followersCount}) =>
      SpeakerProfile(
        slug: slug,
        name: name,
        headline: headline,
        bio: bio,
        photo: photo,
        city: city,
        links: links,
        topics: topics,
        claimed: claimed,
        followersCount: followersCount ?? this.followersCount,
        following: following ?? this.following,
        upcoming: upcoming,
        past: past,
      );

  /// The links, in the order the page shows them: website, LinkedIn, X,
  /// GitHub, then anything else -- only safe http(s) ones.
  static List<PersonLink> linksFrom(Object? value) {
    final json = jsonObject(value);
    if (json == null) {
      // A plain list of addresses, should the server send one.
      return [
        for (final item in value is List ? value : const [])
          if (safeWebLink(item) case final uri?)
            PersonLink(personLinkKindOf(uri), uri),
      ];
    }
    final out = <PersonLink>[];
    for (final (key, kind) in const [
      ('website', PersonLinkKind.website),
      ('linkedin', PersonLinkKind.linkedin),
      ('x', PersonLinkKind.x),
      ('github', PersonLinkKind.github),
      ('other', null),
    ]) {
      final uri = safeWebLink(json[key]);
      if (uri == null) continue;
      out.add(PersonLink(kind ?? personLinkKindOf(uri), uri));
    }
    return out;
  }

  static SpeakerProfile fromJson(Object? value, {required String slug}) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final talks = jsonObject(json['talks']) ?? const <String, dynamic>{};
    return SpeakerProfile(
      slug: _text(json['slug']) ?? slug,
      name: _text(json['name']) ?? 'Speaker',
      headline: _text(json['headline']),
      bio: _text(json['bio']),
      photo: imageUrlFrom(json['photo'],
          prefer: const ['medium', 'large', 'thumbnail', 'original']),
      city: _text(json['city']),
      links: linksFrom(json['links']),
      topics: [
        for (final topic in json['topics'] is List
            ? json['topics'] as List
            : const <Object?>[])
          if (_topicName(topic) case final name?) name,
      ],
      claimed: jsonBool(json['claimed']) == true,
      followersCount: _count(json['followers_count']),
      following: jsonBool(json['following']) == true,
      upcoming: SpeakerTalk.listFrom(talks['upcoming']),
      past: SpeakerTalk.listFrom(talks['past']),
    );
  }
}

/// What `GET /speakers/{slug}` answered.
sealed class SpeakerLookup {
  const SpeakerLookup();
}

/// The page.
class SpeakerFound extends SpeakerLookup {
  const SpeakerFound(this.profile);
  final SpeakerProfile profile;
}

/// The profile was merged into another: its page is at [slug].
class SpeakerMoved extends SpeakerLookup {
  const SpeakerMoved(this.slug);
  final String slug;
}

/// No such page: hidden, removed on request, never there -- or a server
/// without speaker pages yet.
class SpeakerMissing extends SpeakerLookup {
  const SpeakerMissing();
}

/// The merged profile's new address in [value] (`{redirect_slug}`), or
/// null.
String? redirectSlugIn(Object? value) =>
    _text(jsonObject(value)?['redirect_slug']);
