/// A person's profile, as Feature 4 serves it (feature-register
/// `profiles-networking-contract.md`, "Shapes"): the public page anyone
/// may see part of, and the owner's own copy with its settings. Read
/// without trusting any field to be there.
library;

import 'package:finnet/common/models/events/event_page_model.dart'
    show safeWebLink;
import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/shared/utils/image_url.dart';

String? _text(Object? value) {
  final s = jsonString(value)?.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  return s == null || s.isEmpty ? null : s;
}

List<String> _texts(Object? value) => [
      for (final item in value is List ? value : const <Object?>[])
        if (_text(item) case final s?) s,
    ];

String? _picture(Object? value) => imageUrlFrom(value,
    prefer: const ['medium', 'thumbnail', 'large', 'original']);

/// Who may see a part of a profile (`visibility` in the settings).
///
/// - [everyone]: anyone, signed in or not;
/// - [met]: the owner saved them, or they saved the owner;
/// - [mutual]: both saved each other;
/// - [me]: only the owner.
enum Audience { everyone, met, mutual, me }

/// [Audience] from its wire name; [fallback] for anything else.
Audience audienceFrom(Object? value, [Audience fallback = Audience.everyone]) {
  final name = jsonString(value)?.trim().toLowerCase();
  for (final a in Audience.values) {
    if (a.name == name) return a;
  }
  return fallback;
}

extension AudienceWords on Audience {
  String get label => switch (this) {
        Audience.everyone => 'Everyone',
        Audience.met => 'People I met',
        Audience.mutual => 'Mutual connections',
        Audience.me => 'Only me',
      };
}

/// Who gets the owner's email or phone (`share_email`, `share_phone`).
/// Nobody, unless the owner says otherwise.
enum ContactShare { nobody, mutual, met }

ContactShare contactShareFrom(Object? value) {
  final name = jsonString(value)?.trim().toLowerCase();
  for (final c in ContactShare.values) {
    if (c.name == name) return c;
  }
  return ContactShare.nobody;
}

extension ContactShareWords on ContactShare {
  String get label => switch (this) {
        ContactShare.nobody => 'Nobody',
        ContactShare.mutual => 'Mutual connections',
        ContactShare.met => 'People I met',
      };
}

/// The parts of a profile with their own [Audience], in the order the
/// settings list them.
const profileSections = [
  'links',
  'projects',
  'achievements',
  'interests',
  'org'
];

String profileSectionLabel(String section) => switch (section) {
      'links' => 'Links',
      'projects' => 'Projects',
      'achievements' => 'On MyOtherApp',
      'interests' => 'Interests',
      'org' => 'Organisation',
      _ => section,
    };

/// A link's type: the contract's list, in the order the editor offers it.
const profileLinkTypes = [
  'linkedin',
  'github',
  'behance',
  'dribbble',
  'medium',
  'youtube',
  'x',
  'instagram',
  'website',
  'portfolio',
  'other',
];

/// "LinkedIn", "GitHub"... for a link type.
String profileLinkTypeLabel(String type) => switch (type) {
      'linkedin' => 'LinkedIn',
      'github' => 'GitHub',
      'behance' => 'Behance',
      'dribbble' => 'Dribbble',
      'medium' => 'Medium',
      'youtube' => 'YouTube',
      'x' => 'X',
      'instagram' => 'Instagram',
      'website' => 'Website',
      'portfolio' => 'Portfolio',
      _ => 'Link',
    };

/// The type a pasted link is, from its host: a LinkedIn or GitHub address
/// picks its own icon and label. A site the app does not know is a
/// website.
String profileLinkTypeFor(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  bool on(String domain) => host == domain || host.endsWith('.$domain');
  if (on('linkedin.com')) return 'linkedin';
  if (on('github.com')) return 'github';
  if (on('behance.net')) return 'behance';
  if (on('dribbble.com')) return 'dribbble';
  if (on('medium.com')) return 'medium';
  if (on('youtube.com') || on('youtu.be')) return 'youtube';
  if (on('x.com') || on('twitter.com')) return 'x';
  if (on('instagram.com')) return 'instagram';
  return 'website';
}

/// A link a person can be sent to, as the server will take it: http or
/// https, with a host, no user name or password, at most 500 characters.
/// A bare "github.com/asha" is read as https. Null for anything else.
Uri? profileLinkUri(String? text) {
  final uri = safeWebLink(text);
  if (uri == null || uri.userInfo.isNotEmpty) return null;
  if (uri.toString().length > 500) return null;
  return uri;
}

/// One of a profile's links.
class ProfileLink {
  const ProfileLink({required this.type, required this.uri, this.label});

  /// One of [profileLinkTypes].
  final String type;
  final Uri uri;

  /// The owner's own words for it ("My blog"); null for the type's name.
  final String? label;

  /// What the link says: the owner's label, else the type's name.
  String get title => label ?? profileLinkTypeLabel(type);

  /// Null without a link the app would open.
  static ProfileLink? fromJson(Map<String, dynamic> json) {
    final uri = profileLinkUri(_text(json['url']));
    if (uri == null) return null;
    final type = _text(json['type'])?.toLowerCase();
    return ProfileLink(
      type: profileLinkTypes.contains(type) ? type! : profileLinkTypeFor(uri),
      uri: uri,
      label: _text(json['label']),
    );
  }

  static List<ProfileLink> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (fromJson(json) case final link?) link,
      ];

  Map<String, dynamic> toJson() => {
        'type': type,
        'url': uri.toString(),
        if (label != null) 'label': label,
      };

  @override
  bool operator ==(Object other) =>
      other is ProfileLink &&
      other.type == type &&
      other.uri == uri &&
      other.label == label;

  @override
  int get hashCode => Object.hash(type, uri, label);
}

/// One project or piece of portfolio work.
class ProfileProject {
  const ProfileProject({
    this.id,
    required this.title,
    this.summary,
    this.uri,
    this.image,
    this.tags = const [],
    this.role,
    this.month,
  });

  /// Null for one not saved yet.
  final int? id;
  final String title;

  /// One line about it.
  final String? summary;
  final Uri? uri;
  final String? image;

  /// At most [maxTags], each at most [maxTagLength] characters.
  final List<String> tags;

  /// What the owner did on it ("Design lead").
  final String? role;

  /// The month it was done (the first of that month).
  final DateTime? month;

  static const maxTags = 5;
  static const maxTagLength = 24;

  static ProfileProject? fromJson(Map<String, dynamic> json) {
    final title = _text(json['title']);
    if (title == null) return null;
    return ProfileProject(
      id: jsonInt(json['id']),
      title: title,
      summary: _text(json['summary']),
      uri: profileLinkUri(_text(json['url'])),
      image: _picture(json['image']),
      tags: _texts(json['tags']),
      role: _text(json['role']),
      month: _month(json['month']),
    );
  }

  static List<ProfileProject> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (fromJson(json) case final project?) project,
      ];

  /// `2026-11` or `2026-11-01`: the first of the month, as a date.
  static DateTime? _month(Object? value) {
    final text = _text(value);
    if (text == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(text);
    if (m == null) return null;
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    return DateTime(int.parse(m.group(1)!), month);
  }

  /// What `POST`/`PATCH /me/profile/projects` takes. Empty fields are sent
  /// as null, so clearing one clears it.
  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'url': uri?.toString(),
        'tags': tags,
        'role': role,
        'month': month == null
            ? null
            : '${month!.year.toString().padLeft(4, '0')}-'
                '${month!.month.toString().padLeft(2, '0')}-01',
      };

  ProfileProject copyWith({int? id, String? image, bool clearImage = false}) =>
      ProfileProject(
        id: id ?? this.id,
        title: title,
        summary: summary,
        uri: uri,
        image: clearImage ? null : (image ?? this.image),
        tags: tags,
        role: role,
        month: month,
      );
}

class ProfileOrg {
  const ProfileOrg({this.id, required this.name});
  final int? id;
  final String name;

  static ProfileOrg? fromJson(Object? value) {
    final json = jsonObject(value);
    final name = _text(json?['name']);
    return name == null
        ? null
        : ProfileOrg(id: jsonInt(json?['id']), name: name);
  }
}

class ProfileInterest {
  const ProfileInterest({required this.id, required this.name, this.emoji});
  final int id;
  final String name;
  final String? emoji;

  static List<ProfileInterest> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (_text(json['name']) case final name?)
            ProfileInterest(
              id: jsonInt(json['id']) ?? 0,
              name: name,
              emoji: _text(json['emoji']),
            ),
      ];
}

/// A certificate on a profile, linked to its public page.
class ProfileCertificate {
  const ProfileCertificate({required this.eventName, this.uri});
  final String eventName;
  final Uri? uri;
}

/// A talk on a profile, from the speakers directory.
class ProfileTalk {
  const ProfileTalk({required this.eventName, this.title, this.eventSlug});
  final String eventName;
  final String? title;
  final String? eventSlug;

  /// The event's page in the app, when the server named it.
  String? get eventRoute =>
      eventSlug == null ? null : '/events/${Uri.encodeComponent(eventSlug!)}';
}

class ProfileClub {
  const ProfileClub({required this.name, this.slug});
  final String name;
  final String? slug;

  String? get route =>
      slug == null ? null : '/clubs/${Uri.encodeComponent(slug!)}';
}

/// What MyOtherApp itself can vouch for. Each part is null when the owner
/// keeps it off the page (or this viewer may not see it).
class ProfileAchievements {
  const ProfileAchievements({
    this.eventsAttended,
    this.certificates,
    this.talks,
    this.clubs,
  });

  final int? eventsAttended;
  final List<ProfileCertificate>? certificates;
  final List<ProfileTalk>? talks;
  final List<ProfileClub>? clubs;

  bool get isEmpty =>
      (eventsAttended ?? 0) <= 0 &&
      (certificates ?? const []).isEmpty &&
      (talks ?? const []).isEmpty &&
      (clubs ?? const []).isEmpty;

  static ProfileAchievements fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    List<T>? list<T>(String key, T? Function(Map<String, dynamic>) read) {
      if (json[key] is! List) return null;
      return [
        for (final item in jsonObjects(json[key]))
          if (read(item) case final T found) found,
      ];
    }

    final attended = jsonInt(json['events_attended']);
    return ProfileAchievements(
      eventsAttended: attended == null || attended < 0 ? null : attended,
      certificates: list('certificates', (c) {
        final name = _text(c['event_name']);
        return name == null
            ? null
            : ProfileCertificate(
                eventName: name, uri: profileLinkUri(_text(c['url'])));
      }),
      talks: list('talks', (t) {
        final name = _text(t['event_name']);
        return name == null
            ? null
            : ProfileTalk(
                eventName: name,
                title: _text(t['title']),
                eventSlug: _text(t['event_slug']));
      }),
      clubs: list('clubs', (c) {
        final name = _text(c['name']);
        return name == null
            ? null
            : ProfileClub(name: name, slug: _text(c['slug']));
      }),
    );
  }
}

/// Where the viewer stands with the owner. Null when anonymous, and on
/// the owner's own page.
class ProfileRelation {
  const ProfileRelation({
    this.savedByMe = false,
    this.savedMe = false,
    this.mutual = false,
    this.networkId,
  });

  final bool savedByMe;
  final bool savedMe;
  final bool mutual;

  /// The viewer's entry for the owner in their network, once saved.
  final int? networkId;

  static ProfileRelation? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    return ProfileRelation(
      savedByMe: jsonBool(json['saved_by_me']) == true,
      savedMe: jsonBool(json['saved_me']) == true,
      mutual: jsonBool(json['mutual']) == true,
      networkId: jsonInt(json['network_id']),
    );
  }

  ProfileRelation saved(int? networkId, {bool? mutual}) => ProfileRelation(
        savedByMe: true,
        savedMe: savedMe,
        mutual: mutual ?? savedMe,
        networkId: networkId ?? this.networkId,
      );

  ProfileRelation get removed => ProfileRelation(savedMe: savedMe);
}

/// The public page at `myotherapp.in/u/<handle>`, as this viewer may see
/// it: the parts they may not are empty, and named in [hiddenSections].
class PublicProfile {
  const PublicProfile({
    required this.handle,
    required this.fullName,
    this.userId,
    this.picture,
    this.headline,
    this.bio,
    this.city,
    this.org,
    this.interests = const [],
    this.links = const [],
    this.projects = const [],
    this.achievements = const ProfileAchievements(),
    this.email,
    this.phone,
    this.hiddenSections = const {},
    this.private = false,
    this.indexable = false,
    this.isMe = false,
    this.relation,
  });

  final String handle;
  final String fullName;

  /// The owner's account, when the server says (for blocking and
  /// reporting).
  final int? userId;
  final String? picture;
  final String? headline;
  final String? bio;
  final String? city;
  final ProfileOrg? org;
  final List<ProfileInterest> interests;
  final List<ProfileLink> links;
  final List<ProfileProject> projects;
  final ProfileAchievements achievements;

  /// Shared with this viewer by the owner's choice; null otherwise.
  final String? email;
  final String? phone;

  /// What this viewer can't see: [profileSections] names.
  final Set<String> hiddenSections;

  /// A private profile shows strangers only the name, picture and
  /// headline, until the owner saves them.
  final bool private;
  final bool indexable;
  final bool isMe;
  final ProfileRelation? relation;

  /// "Ananya Iyer" -> "AI".
  String get initials => initialsOf(fullName);

  /// `https://myotherapp.in/u/<handle>`.
  Uri get publicUri => publicProfileUri(handle);

  /// Only the name, picture and headline came: a private profile, seen
  /// by a stranger.
  bool get locked => private && !isMe && !(relation?.savedMe ?? false);

  static PublicProfile? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    final handle = _text(json['handle'])?.toLowerCase();
    if (handle == null) return null;
    final contact = jsonObject(json['contact']);
    return PublicProfile(
      handle: handle,
      fullName: _text(json['full_name']) ?? _text(json['name']) ?? handle,
      userId: jsonInt(json['user_id']),
      picture: _picture(json['picture']),
      headline: _text(json['headline']),
      bio: _text(json['bio']),
      city: _text(json['city']),
      org: ProfileOrg.fromJson(json['org']),
      interests: ProfileInterest.listFrom(json['interests']),
      links: ProfileLink.listFrom(json['links']),
      projects: ProfileProject.listFrom(json['projects']),
      achievements: ProfileAchievements.fromJson(json['achievements']),
      email: _text(contact?['email']),
      phone: _text(contact?['phone']),
      hiddenSections: {
        for (final s in _texts(json['hidden_sections'])) s.toLowerCase(),
      },
      private: jsonBool(json['private']) == true,
      indexable: jsonBool(json['indexable']) == true,
      isMe: jsonBool(json['is_me']) == true,
      relation: ProfileRelation.fromJson(json['relation']),
    );
  }

  PublicProfile copyWith({
    ProfileRelation? relation,
    bool clearRelation = false,
    List<ProfileLink>? links,
    List<ProfileProject>? projects,
  }) =>
      PublicProfile(
        handle: handle,
        fullName: fullName,
        userId: userId,
        picture: picture,
        headline: headline,
        bio: bio,
        city: city,
        org: org,
        interests: interests,
        links: links ?? this.links,
        projects: projects ?? this.projects,
        achievements: achievements,
        email: email,
        phone: phone,
        hiddenSections: hiddenSections,
        private: private,
        indexable: indexable,
        isMe: isMe,
        relation: clearRelation ? null : (relation ?? this.relation),
      );
}

/// "Ananya Iyer" -> "AI"; "?" for no name.
String initialsOf(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = String.fromCharCode(words.first.runes.first);
  final last =
      words.length > 1 ? String.fromCharCode(words.last.runes.first) : '';
  return '$first$last'.toUpperCase();
}

/// `https://myotherapp.in/u/<handle>`: the profile's page on the website.
Uri publicProfileUri(String handle) => Uri.parse(AppConfig.publicSiteUrl)
    .replace(path: '/u/${Uri.encodeComponent(handle)}');

/// The owner's own choices about their profile.
class ProfileSettings {
  const ProfileSettings({
    this.visibility = const {},
    this.shareEmail = ContactShare.nobody,
    this.sharePhone = ContactShare.nobody,
    this.isPrivate = false,
    this.indexable = false,
    this.notifySaves = true,
    this.recapEmails = true,
    this.scanningEnabled = true,
    this.showEvents = false,
    this.showCertificates = true,
    this.showTalks = true,
    this.showClubs = false,
  });

  /// By [profileSections] name; a part not named is [Audience.everyone].
  final Map<String, Audience> visibility;
  final ContactShare shareEmail;
  final ContactShare sharePhone;
  final bool isPrivate;
  final bool indexable;
  final bool notifySaves;
  final bool recapEmails;
  final bool scanningEnabled;
  final bool showEvents;
  final bool showCertificates;
  final bool showTalks;
  final bool showClubs;

  Audience audienceOf(String section) =>
      visibility[section] ?? Audience.everyone;

  static ProfileSettings fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final seen = jsonObject(json['visibility']) ?? const <String, dynamic>{};
    bool flag(String key, bool fallback) => jsonBool(json[key]) ?? fallback;
    return ProfileSettings(
      visibility: {
        for (final section in profileSections)
          if (seen.containsKey(section)) section: audienceFrom(seen[section]),
      },
      shareEmail: contactShareFrom(json['share_email']),
      sharePhone: contactShareFrom(json['share_phone']),
      isPrivate: flag('is_private', false),
      indexable: flag('indexable', false),
      notifySaves: flag('notify_saves', true),
      recapEmails: flag('recap_emails', true),
      scanningEnabled: flag('scanning_enabled', true),
      showEvents: flag('show_events', false),
      showCertificates: flag('show_certificates', true),
      showTalks: flag('show_talks', true),
      showClubs: flag('show_clubs', false),
    );
  }

  /// The whole `visibility` object, as `PATCH /me/profile` takes it.
  Map<String, String> visibilityJson([Map<String, Audience>? changed]) => {
        for (final section in profileSections)
          section: (changed?[section] ?? audienceOf(section)).name,
      };
}

/// How much of the profile is filled in: what the app nudges for.
class ProfileCompleteness {
  const ProfileCompleteness({this.score = 0, this.missing = const []});

  /// 0 to 100.
  final int score;

  /// `headline`, `links`, `projects`, `photo`: what is still missing.
  final List<String> missing;

  bool get complete => score >= 100 || missing.isEmpty && score > 0;

  static ProfileCompleteness fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final score = (jsonInt(json['score']) ?? 0).clamp(0, 100);
    return ProfileCompleteness(score: score, missing: _texts(json['missing']));
  }

  static String missingLabel(String part) => switch (part) {
        'headline' => 'a headline',
        'links' => 'a link',
        'projects' => 'a project',
        'photo' => 'a photo',
        _ => part,
      };
}

/// `GET /me/profile`: the owner's page as they see it, with its settings.
class MyProfile {
  const MyProfile({
    required this.profile,
    this.settings = const ProfileSettings(),
    this.completeness = const ProfileCompleteness(),
    this.email,
    this.phone,
  });

  final PublicProfile profile;
  final ProfileSettings settings;
  final ProfileCompleteness completeness;

  /// Their own, for the contact-sharing settings to say what is shared.
  final String? email;
  final String? phone;

  String get handle => profile.handle;

  static MyProfile? fromJson(Object? value) {
    final json = jsonObject(value);
    final profile = PublicProfile.fromJson(json);
    if (json == null || profile == null) return null;
    return MyProfile(
      profile: profile,
      settings: ProfileSettings.fromJson(json['settings']),
      completeness: ProfileCompleteness.fromJson(json['completeness']),
      email: _text(json['email']),
      phone: _text(json['phone']),
    );
  }

  MyProfile withProjects(List<ProfileProject> projects) => MyProfile(
        profile: profile.copyWith(projects: projects),
        settings: settings,
        completeness: completeness,
        email: email,
        phone: phone,
      );
}

/// Someone, briefly: a row in the network or the "saved you" list.
class PersonBrief {
  const PersonBrief({
    required this.fullName,
    this.userId,
    this.handle,
    this.picture,
    this.headline,
    this.orgName,
  });

  final int? userId;

  /// Null for a deleted account: there is no page to open.
  final String? handle;
  final String fullName;
  final String? picture;
  final String? headline;
  final String? orgName;

  /// Their profile in the app, when they have one.
  String? get route => handle == null ? null : profileRoute(handle!);

  String get initials => initialsOf(fullName);

  /// "Flutter dev · CET": what they do, and where.
  String? get line {
    final parts = [headline, orgName].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static PersonBrief fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    return PersonBrief(
      userId: jsonInt(json['user_id']),
      handle: _text(json['handle'])?.toLowerCase(),
      fullName:
          _text(json['full_name']) ?? _text(json['name']) ?? 'Deleted user',
      picture: _picture(json['picture']),
      headline: _text(json['headline']),
      orgName: _text(json['org_name']),
    );
  }
}
