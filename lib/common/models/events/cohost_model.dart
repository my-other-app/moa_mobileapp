import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/shared/utils/image_url.dart';

// Co-hosted events (feature-register `cohosts-contract.md`; the API's
// docs/COHOSTS.md): a host club invites other clubs to run its event with
// it. The host stays the event's `club`; the clubs that accepted come as
// `cohosts`, a list of `{club_id, name, slug, logo}` in the order they
// accepted. Under `/events/*` and `/clubs/*` the logo is the S3 sizes, as
// the event's `club.logo`; under `/discover/*` it is one URL.
//
// A server older than the feature sends no `cohosts`: the list is empty,
// and every screen shows the event as it always did.

/// One club co-hosting an event, beside its host.
class EventCohost {
  /// The club's id (`club_id`); 0 when the server sent none, and the club
  /// can then not be opened.
  final int clubId;
  final String name;
  final String slug;

  /// The logo's URL, the smallest size first; null for none.
  final String? logo;

  const EventCohost({
    required this.clubId,
    required this.name,
    this.slug = '',
    this.logo,
  });

  /// One `CohostRef`; null without a name.
  static EventCohost? fromJson(Map<String, dynamic> json) {
    final name = jsonString(json['name'])?.trim() ?? '';
    if (name.isEmpty) return null;
    final id = jsonInt(json['club_id']) ?? jsonInt(json['id']) ?? 0;
    return EventCohost(
      clubId: id > 0 ? id : 0,
      name: name,
      slug: jsonString(json['slug'])?.trim() ?? '',
      logo: imageUrlFrom(json['logo']),
    );
  }

  /// Every co-host in [value] (a list), in its order: a row without a name
  /// is skipped, a club named twice is kept once, and the host itself
  /// ([hostId]) is never its own co-host. Absent, null or not a list (an
  /// older server): none.
  static List<EventCohost> listFrom(Object? value, {int? hostId}) {
    final seen = <int>{};
    final cohosts = <EventCohost>[];
    for (final json in jsonObjects(value)) {
      final cohost = fromJson(json);
      if (cohost == null) continue;
      final id = cohost.clubId;
      if (id > 0 && (id == hostId || !seen.add(id))) continue;
      cohosts.add(cohost);
    }
    return cohosts;
  }

  /// "Robotics Club" -> "RC"; "?" without a name.
  String get initials => clubInitials(name);
}

/// A club's initials for a logo it has none of: "Robotics Club" -> "RC".
String clubInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

/// The names in [names] as a sentence: "A", "A and B", "A, B and C".
String joinClubNames(List<String> names) {
  final shown = [
    for (final name in names)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (shown.length <= 1) return shown.isEmpty ? '' : shown.single;
  return '${shown.sublist(0, shown.length - 1).join(', ')} and ${shown.last}';
}

/// "Hosted by A and B", "Hosted by A, B and C": the host, then its
/// co-hosts in their order.
String hostedByText(String host, List<String> cohosts) =>
    'Hosted by ${joinClubNames([host, ...cohosts])}';

/// Who runs the event, short enough for a card's one line: the host alone
/// ("A") without co-hosts, "A and B" with one, "A + 2" with more.
String hostNamesCompact(String host, List<String> cohosts) {
  final others = [
    for (final name in cohosts)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (others.isEmpty) return host;
  if (others.length == 1) return '${host.trim()} and ${others.single}';
  return '${host.trim()} + ${others.length}';
}
