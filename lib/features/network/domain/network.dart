/// The person's network: everyone they saved, and where and how they met
/// (feature-register `profiles-networking-contract.md`, "Network").
library;

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/network/domain/profile.dart';

String? _text(Object? value) {
  final s = jsonString(value)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// How two people met: the server's `method`.
enum MetHow { qr, discovery, link, search }

MetHow? metHowFrom(Object? value) {
  final name = _text(value)?.toLowerCase();
  for (final m in MetHow.values) {
    if (m.name == name) return m;
  }
  return null;
}

extension MetHowWords on MetHow {
  String get label => switch (this) {
        MetHow.qr => 'Scanned their QR',
        MetHow.discovery => 'People Like You',
        MetHow.link => 'Their profile link',
        MetHow.search => 'Search',
      };
}

/// An event a meeting happened at.
class NetworkEventRef {
  const NetworkEventRef({
    required this.id,
    required this.name,
    this.slug,
    this.startsAt,
  });

  final int id;
  final String name;
  final String? slug;
  final DateTime? startsAt;

  String get route => '/events/${Uri.encodeComponent(slug ?? '$id')}';

  static NetworkEventRef? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = jsonInt(json?['id']);
    if (json == null || id == null) return null;
    return NetworkEventRef(
      id: id,
      name: _text(json['name']) ?? 'An event',
      slug: _text(json['slug']),
      startsAt: jsonDate(json['starts_at']),
    );
  }
}

/// One meeting: at an event (or not), how, and when.
class Encounter {
  const Encounter({this.event, this.method, this.metAt});

  final NetworkEventRef? event;
  final MetHow? method;
  final DateTime? metAt;

  static List<Encounter> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          Encounter(
            event: NetworkEventRef.fromJson(json['event']),
            method: metHowFrom(json['method']),
            metAt: jsonDate(json['met_at']),
          ),
      ];
}

/// One person in the network, with the owner's private note and tags.
class NetworkPerson {
  const NetworkPerson({
    required this.id,
    required this.person,
    this.mutual = false,
    this.savedMe = false,
    this.note,
    this.tags = const [],
    this.firstMetAt,
    this.lastMetAt,
    this.encounters = const [],
  });

  final int id;
  final PersonBrief person;

  /// Both saved each other.
  final bool mutual;
  final bool savedMe;

  /// Private to the owner; at most [maxNote] characters.
  final String? note;

  /// Private to the owner; at most [maxTags], each [maxTagLength].
  final List<String> tags;
  final DateTime? firstMetAt;
  final DateTime? lastMetAt;

  /// Newest first: the last 3 in the list, all of them in the detail.
  final List<Encounter> encounters;

  static const maxNote = 500;
  static const maxTags = 10;
  static const maxTagLength = 24;

  static NetworkPerson? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = jsonInt(json?['id']);
    if (json == null || id == null) return null;
    return NetworkPerson(
      id: id,
      person: PersonBrief.fromJson(json['person']),
      mutual: jsonBool(json['mutual']) == true,
      savedMe: jsonBool(json['saved_me']) == true,
      note: _text(json['note']),
      tags: [
        for (final t in json['tags'] is List ? json['tags'] as List : const [])
          if (_text(t) case final tag?) tag,
      ],
      firstMetAt: jsonDate(json['first_met_at']),
      lastMetAt: jsonDate(json['last_met_at']),
      encounters: Encounter.listFrom(json['encounters']),
    );
  }

  static List<NetworkPerson> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (fromJson(json) case final person?) person,
      ];

  /// The events they were met at, newest first, each once.
  List<NetworkEventRef> get events {
    final seen = <int>{};
    return [
      for (final e in encounters)
        if (e.event case final event? when seen.add(event.id)) event,
    ];
  }

  NetworkPerson copyWith({String? note, bool clearNote = false, List<String>? tags}) =>
      NetworkPerson(
        id: id,
        person: person,
        mutual: mutual,
        savedMe: savedMe,
        note: clearNote ? null : (note ?? this.note),
        tags: tags ?? this.tags,
        firstMetAt: firstMetAt,
        lastMetAt: lastMetAt,
        encounters: encounters,
      );
}

/// An event in the network's filter, with how many were met there.
class NetworkEventCount {
  const NetworkEventCount(this.event, this.count);
  final NetworkEventRef event;
  final int count;
}

class NetworkTagCount {
  const NetworkTagCount(this.tag, this.count);
  final String tag;
  final int count;
}

/// One page of `GET /network`, with the filters' counts.
class NetworkList {
  const NetworkList({
    this.items = const [],
    this.total = 0,
    this.events = const [],
    this.tags = const [],
  });

  final List<NetworkPerson> items;
  final int total;
  final List<NetworkEventCount> events;
  final List<NetworkTagCount> tags;

  static NetworkList fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final items = NetworkPerson.listFrom(json['items']);
    return NetworkList(
      items: items,
      total: jsonInt(json['total']) ?? items.length,
      events: [
        for (final e in jsonObjects(json['events']))
          if (NetworkEventRef.fromJson(e['event']) case final event?)
            NetworkEventCount(event, jsonInt(e['count']) ?? 0),
      ],
      tags: [
        for (final t in jsonObjects(json['tags']))
          if (_text(t['tag']) case final tag?)
            NetworkTagCount(tag, jsonInt(t['count']) ?? 0),
      ],
    );
  }

  NetworkEventCount? eventCount(int eventId) {
    for (final e in events) {
      if (e.event.id == eventId) return e;
    }
    return null;
  }
}

/// How the network is sorted: newest saved, by name, by last met.
enum NetworkSort { recent, name, met }

extension NetworkSortWords on NetworkSort {
  String get label => switch (this) {
        NetworkSort.recent => 'Newest',
        NetworkSort.name => 'A to Z',
        NetworkSort.met => 'Last met',
      };
}

/// What the network list is asked for.
class NetworkQuery {
  const NetworkQuery({
    this.q = '',
    this.eventId,
    this.tag,
    this.mutualOnly = false,
    this.sort = NetworkSort.recent,
    this.page = 1,
    this.pageSize = 50,
  });

  final String q;
  final int? eventId;
  final String? tag;
  final bool mutualOnly;
  final NetworkSort sort;
  final int page;
  final int pageSize;

  Map<String, dynamic> toParams() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (eventId != null) 'event_id': eventId,
        if (tag != null) 'tag': tag,
        if (mutualOnly) 'mutual': true,
        'sort': sort.name,
        // A to Z reads up; the others newest first.
        'order': sort == NetworkSort.name ? 'asc' : 'desc',
        'page': page,
        'page_size': pageSize,
      };

  NetworkQuery copyWith({
    String? q,
    int? eventId,
    bool clearEvent = false,
    String? tag,
    bool clearTag = false,
    bool? mutualOnly,
    NetworkSort? sort,
  }) =>
      NetworkQuery(
        q: q ?? this.q,
        eventId: clearEvent ? null : (eventId ?? this.eventId),
        tag: clearTag ? null : (tag ?? this.tag),
        mutualOnly: mutualOnly ?? this.mutualOnly,
        sort: sort ?? this.sort,
        pageSize: pageSize,
      );

  bool get filtered =>
      q.trim().isNotEmpty || eventId != null || tag != null || mutualOnly;

  @override
  bool operator ==(Object other) =>
      other is NetworkQuery &&
      other.q == q &&
      other.eventId == eventId &&
      other.tag == tag &&
      other.mutualOnly == mutualOnly &&
      other.sort == sort &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode =>
      Object.hash(q, eventId, tag, mutualOnly, sort, page, pageSize);
}

/// What saving someone left: their entry, whether it is new, and their
/// profile as the saver may now see it.
class SaveResult {
  const SaveResult({
    required this.person,
    this.created = true,
    this.newEncounter = true,
    this.profile,
  });

  final NetworkPerson person;
  final bool created;
  final bool newEncounter;
  final PublicProfile? profile;

  static SaveResult? fromJson(Object? value) {
    final json = jsonObject(value);
    final person = NetworkPerson.fromJson(json?['person']);
    if (json == null || person == null) return null;
    return SaveResult(
      person: person,
      created: jsonBool(json['created']) ?? true,
      newEncounter: jsonBool(json['new_encounter']) ?? true,
      profile: PublicProfile.fromJson(json['profile']),
    );
  }
}

/// Someone who saved the person, whom they haven't saved back.
class SavedMeEntry {
  const SavedMeEntry({required this.person, this.savedAt, this.event});

  final PersonBrief person;
  final DateTime? savedAt;
  final NetworkEventRef? event;

  static List<SavedMeEntry> listFrom(Object? value) => [
        for (final json in jsonObjects(jsonObject(value)?['items'] ?? value))
          SavedMeEntry(
            person: PersonBrief.fromJson(json['person']),
            savedAt: jsonDate(json['saved_at']),
            event: NetworkEventRef.fromJson(json['event']),
          ),
      ];
}

/// The person's own QR: the code, and the link it holds.
class MyQr {
  const MyQr({required this.code, required this.url, this.createdAt});

  final String code;

  /// `https://myotherapp.in/p/<code>`: what the QR holds.
  final String url;
  final DateTime? createdAt;

  static MyQr? fromJson(Object? value) {
    final json = jsonObject(value);
    final code = _text(json?['code']);
    final url = _text(json?['url']);
    if (code == null || url == null) return null;
    return MyQr(code: code, url: url, createdAt: jsonDate(json?['created_at']));
  }
}
