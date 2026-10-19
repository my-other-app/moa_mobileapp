import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    as entity;
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// A club's page, from either of the two places the server describes one:
///
/// - `GET /clubs/info/{id}` ([ClubInfo.fromJson]) -- needs a session, and
///   carries what is personal: whether you follow or pinned it, its rating,
///   its college, a phone number.
/// - `GET /discover/clubs/{slug}` ([ClubInfo.fromDiscoverJson]) -- public,
///   the website's club page: no follow state, but the club's own site
///   ([websiteUrl]) and how many events it has held.
///
/// Both carry the cover, the tagline, the team and the partners.
class ClubInfo {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic> logo;

  /// The banner across the top; null when the club has none.
  final String? coverUrl;

  /// One line under the name; empty when the club wrote none.
  final String tagline;
  final String locationName;
  final String locationLink;
  final String about;
  final double rating;
  final int totalRatings;
  final Map<String, dynamic> socials;
  final List<Interest> interests;

  /// The club's `topics`; null from a server that does not send them, when
  /// they are worked out from [interests] instead.
  final List<Topic>? topics;
  final int followersCount;
  final String contactPhone;
  final String contactEmail;
  final Map<String, dynamic> userData;
  final Org org;

  /// The people who run it, in the club's order.
  final List<ClubTeamMember> team;

  /// Who backs it, in the club's order.
  final List<ClubPartner> partners;

  /// The club's own site on MyOtherApp (`{slug}.myotherapp.in`, or its own
  /// domain), when it has published one. Only the public page says.
  final String? websiteUrl;

  /// Events held so far. Only the public page says.
  final int? eventsHeld;

  /// Read from the public page: nothing personal in it, so whether this
  /// person follows the club is not known.
  final bool isPublicView;

  ClubInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.logo,
    this.coverUrl,
    this.tagline = '',
    required this.locationName,
    required this.locationLink,
    required this.about,
    required this.rating,
    required this.totalRatings,
    required this.socials,
    required this.interests,
    this.topics,
    required this.followersCount,
    required this.contactPhone,
    required this.contactEmail,
    required this.userData,
    required this.org,
    this.team = const [],
    this.partners = const [],
    this.websiteUrl,
    this.eventsHeld,
    this.isPublicView = false,
  });

  bool get isFollowing => userData['is_following'] == true;

  /// The link behind "Visit website": the club's site on MyOtherApp when it
  /// has one, else the website it gave. Only http(s), as on the website.
  String? get website =>
      safeWebUrl(websiteUrl) ?? safeWebUrl(jsonString(socials['website']));

  /// `GET /clubs/info/{id}`.
  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: jsonInt(json['id']) ?? 0,
      name: jsonText(json['name']),
      slug: jsonText(json['slug']),
      // A dict normally; null for a club with no logo, and a bare URL on
      // older rows. Kept as a map either way so the page never casts.
      logo: _logoMap(json['logo']),
      coverUrl: imageUrlFrom(json['cover'],
          prefer: const ['large', 'original', 'medium', 'thumbnail']),
      tagline: jsonText(json['tagline']).trim(),
      locationName: jsonText(json['location_name']),
      locationLink: jsonText(json['location_link']),
      about: jsonText(json['about']),
      rating: jsonDouble(json['rating']) ?? 0.0,
      totalRatings: jsonInt(json['total_ratings']) ?? 0,
      socials: json['socials'] is Map
          ? Map<String, dynamic>.from(json['socials'])
          : <String, dynamic>{},
      interests: jsonObjects(json['interests']).map(Interest.fromJson).toList(),
      topics: TopicModel.declaredIn(json),
      followersCount: jsonInt(json['followers_count']) ?? 0,
      contactPhone: jsonText(json['contact_phone']),
      contactEmail: jsonText(json['contact_email']),
      userData: json['user_data'] is Map
          ? Map<String, dynamic>.from(json['user_data'])
          : <String, dynamic>{},
      org: Org.fromJson(jsonObject(json['org']) ?? const <String, dynamic>{}),
      team: _ordered(_named(json['team'], ClubTeamMember.fromJson)),
      partners: _ordered(_named(json['partners'], ClubPartner.fromJson)),
    );
  }

  /// `GET /discover/clubs/{slug}`: `{club, upcoming, past, threads, team,
  /// partners}`.
  factory ClubInfo.fromDiscoverJson(Map<String, dynamic> json) {
    final club = jsonObject(json['club']) ?? const <String, dynamic>{};
    final logo = jsonString(club['logo']);
    return ClubInfo(
      id: jsonInt(club['id']) ?? 0,
      name: jsonText(club['name']),
      slug: jsonText(club['slug']),
      logo: logo == null ? <String, dynamic>{} : _logoMap(logo),
      coverUrl: imageUrlFrom(club['cover']),
      tagline: jsonText(club['tagline']).trim(),
      locationName: jsonText(club['location_name']),
      locationLink: '',
      about: jsonText(club['about']),
      rating: 0,
      totalRatings: 0,
      socials: club['socials'] is Map
          ? Map<String, dynamic>.from(club['socials'])
          : <String, dynamic>{},
      // Names only, here.
      interests: [
        for (final name in _list(club['interests']))
          if (name is String && name.trim().isNotEmpty)
            Interest(id: 0, name: name.trim(), icon: '', iconType: ''),
      ],
      topics: TopicModel.declaredIn(club),
      followersCount: jsonInt(club['followers']) ?? 0,
      contactPhone: '',
      contactEmail: jsonText(club['contact_email']),
      userData: const <String, dynamic>{},
      org: Org.fromJson(const <String, dynamic>{}),
      // Already in the club's order.
      team: _named(json['team'], ClubTeamMember.fromJson).toList(),
      partners: _named(json['partners'], ClubPartner.fromJson).toList(),
      websiteUrl: jsonString(club['website_url']),
      eventsHeld: jsonInt(club['events_held']),
      isPublicView: true,
    );
  }
}

/// The club's logo as a map, whatever shape the server sent it in.
Map<String, dynamic> _logoMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  final url = imageUrlFrom(value);
  return url == null
      ? <String, dynamic>{}
      : {'thumbnail': url, 'original': url};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

/// The entries of [value] read with [read], leaving out any without a name
/// (there is nothing to show for one).
Iterable<T> _named<T extends _Sorted>(
  Object? value,
  T Function(Map<String, dynamic>) read,
) =>
    jsonObjects(value).map(read).where((item) => item.name.isNotEmpty);

/// [items] in the club's chosen order (`sort_order`), ties as sent.
List<T> _ordered<T extends _Sorted>(Iterable<T> items) {
  final list = items.toList();
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final bySort = a.$2.sortOrder.compareTo(b.$2.sortOrder);
    return bySort != 0 ? bySort : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexed) item];
}

abstract class _Sorted {
  String get name;
  int get sortOrder;
}

/// [url] as a link it is safe to open: `https://` added when a club typed
/// none, and anything but http(s) refused (null), as the website does.
String? safeWebUrl(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return null;
  // `mailto:`, `javascript:` and the like are refused outright; a colon
  // before a number is a port (`example.org:8080`), not a scheme.
  final scheme =
      RegExp(r'^([a-z][a-z0-9+.-]*):(?!//)(?!\d)', caseSensitive: false)
          .firstMatch(raw);
  if (scheme != null) return null;
  final withScheme =
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(raw)
          ? raw
          : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (!uri.isScheme('http') && !uri.isScheme('https')) return null;
  return uri.toString();
}

/// The host of a website, for a link's label: `tinkerhub.org`.
String hostLabel(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return url;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// One of the people who run a club.
class ClubTeamMember implements _Sorted {
  @override
  final String name;

  /// "President", "Design lead"; empty when not given.
  final String role;
  final String? photoUrl;
  final String? instagram;
  final String? linkedin;
  final String? x;
  final String? website;
  @override
  final int sortOrder;

  const ClubTeamMember({
    required this.name,
    this.role = '',
    this.photoUrl,
    this.instagram,
    this.linkedin,
    this.x,
    this.website,
    this.sortOrder = 0,
  });

  /// Either shape: the club detail's (links beside the name, the photo an
  /// image dict) or the public page's (`links: {...}`, the photo a URL).
  factory ClubTeamMember.fromJson(Map<String, dynamic> json) {
    final links = jsonObject(json['links']) ?? json;
    String? link(String key) => safeWebUrl(jsonString(links[key]));
    return ClubTeamMember(
      name: jsonText(json['name']).trim(),
      role: jsonText(json['role']).trim(),
      photoUrl: imageUrlFrom(json['photo'],
          prefer: const ['medium', 'thumbnail', 'original', 'large']),
      instagram: link('instagram'),
      linkedin: link('linkedin'),
      x: link('x'),
      website: link('website'),
      sortOrder: jsonInt(json['sort_order']) ?? 0,
    );
  }

  /// The links worth showing, in the website's order: (kind, url).
  List<(String, String)> get links => [
        if (instagram != null) ('instagram', instagram!),
        if (linkedin != null) ('linkedin', linkedin!),
        if (x != null) ('x', x!),
        if (website != null) ('website', website!),
      ];
}

/// Someone who backs a club: a sponsor, a partner organisation.
class ClubPartner implements _Sorted {
  @override
  final String name;

  /// "Title sponsor", "Venue partner"; empty when not given.
  final String role;

  /// The year they started, when the club said.
  final int? since;
  final String? logoUrl;
  @override
  final int sortOrder;

  const ClubPartner({
    required this.name,
    this.role = '',
    this.since,
    this.logoUrl,
    this.sortOrder = 0,
  });

  factory ClubPartner.fromJson(Map<String, dynamic> json) => ClubPartner(
        name: jsonText(json['name']).trim(),
        role: jsonText(json['role']).trim(),
        since: jsonInt(json['since']),
        logoUrl: imageUrlFrom(json['logo'],
            prefer: const ['medium', 'thumbnail', 'original', 'large']),
        sortOrder: jsonInt(json['sort_order']) ?? 0,
      );
}

class Interest {
  final int id;
  final String name;
  final String icon;
  final String iconType;

  /// Its topic; null from a server that does not say.
  final int? categoryId;

  Interest({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconType,
    this.categoryId,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: jsonInt(json['id']) ?? 0,
      name: jsonText(json['name']),
      icon: jsonText(json['icon']),
      iconType: jsonText(json['icon_type']),
      categoryId: jsonInt(json['category_id']),
    );
  }

  entity.Interest toEntity() => entity.Interest(
        id: id,
        name: name,
        icon: icon.isEmpty ? null : icon,
        iconType: iconType.isEmpty ? null : iconType,
        categoryId: categoryId,
      );
}

class Org {
  final int id;
  final String name;
  final String type;
  final String address;
  final String phone;
  final String email;

  Org({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.email,
  });

  factory Org.fromJson(Map<String, dynamic> json) {
    return Org(
      id: jsonInt(json['id']) ?? 0,
      name: jsonText(json['name']),
      type: jsonText(json['type']),
      address: jsonText(json['address']),
      phone: jsonText(json['phone']),
      email: jsonText(json['email']),
    );
  }
}
