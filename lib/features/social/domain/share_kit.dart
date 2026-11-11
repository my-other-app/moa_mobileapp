/// A share kit (feature-register `social-posting-contract.md`, "Share
/// kit"): each platform's words and poster for an event the person's club
/// just published, for them to post from their own accounts. Read without
/// trusting any field to be there.
library;

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// The push the host club's team gets when an event is published
/// (`share_kit`, data `{event_id}`): it opens the event's share kit.
const shareKitType = 'share_kit';

/// The app's screens.
const shareKitsLocation = '/profile/share-kits';
String shareKitRoute(int eventId) => '$shareKitsLocation/$eventId';

String? _text(Object? value) {
  final s = jsonString(value)?.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  return s == null || s.isEmpty ? null : s;
}

/// The event a kit is for.
class ShareKitEvent {
  const ShareKitEvent({
    required this.id,
    required this.name,
    this.slug,
    this.date,
    this.clubName,
    this.poster,
  });

  final int id;
  final String name;
  final String? slug;
  final DateTime? date;
  final String? clubName;
  final String? poster;

  /// The event's `{id, name, date, slug}` -- or a row that is the event
  /// itself (`event_id`, `event_name`) -- or null without an id.
  static ShareKitEvent? fromJson(Object? value) {
    final row = jsonObject(value);
    if (row == null) return null;
    final json = jsonObject(row['event']) ?? row;
    final id = jsonInt(json['id']) ?? jsonInt(row['event_id']);
    if (id == null) return null;
    final club = jsonObject(json['club']) ?? jsonObject(row['club']);
    return ShareKitEvent(
      id: id,
      name: _text(json['name']) ?? _text(row['event_name']) ?? 'Event',
      slug: _text(json['slug']),
      date: jsonDate(json['date']) ??
          jsonDate(json['starts_at']) ??
          jsonDate(json['event_datetime']),
      clubName: _text(club?['name']) ?? _text(row['club_name']),
      poster: imageUrlFrom(
          json['poster'] ?? json['image_url'] ?? row['poster'] ?? row['image_url'],
          prefer: const ['thumbnail', 'medium', 'large', 'original']),
    );
  }

  /// `GET /social/share-kits`: a bare list, or the list under `items`.
  static List<ShareKitEvent> listFrom(Object? value) {
    final items = value is List
        ? value
        : (jsonObject(value)?['items'] ?? jsonObject(value)?['events']);
    return [
      for (final json in jsonObjects(items))
        if (fromJson(json) case final event?) event,
    ];
  }
}

/// One platform's part of the kit.
class ShareKitPost {
  const ShareKitPost({
    required this.platform,
    required this.text,
    this.imageUrl,
    this.link,
  });

  /// The server's name for it: `instagram`, `whatsapp_status`, `linkedin`…
  final String platform;
  final String text;
  final String? imageUrl;
  final Uri? link;

  /// "Instagram", "WhatsApp Status", "LinkedIn"…
  String get label => shareKitPlatformLabel(platform);

  /// Instagram (feed or story) and WhatsApp Status ignore words another
  /// app hands them: the caption is copied first, then the poster shared.
  /// WhatsApp is one platform in the kit, for a chat or for Status, so it
  /// copies too.
  bool get copiesCaptionFirst => captionFirstPlatform(platform);

  /// The words go to the share sheet with the poster: everywhere but
  /// Instagram, which drops them (a WhatsApp chat keeps them as the
  /// picture's caption).
  bool get sendsWordsWithPoster => !platform.startsWith('instagram');

  /// The app the person pastes the caption into: "Instagram", "WhatsApp".
  String get pasteInto =>
      platform.startsWith('whatsapp') ? 'WhatsApp' : label.split(' ').first;

  static ShareKitPost? fromJson(Map<String, dynamic> json) {
    final platform = _text(json['platform'])?.toLowerCase();
    final text = _text(json['text']);
    if (platform == null || text == null) return null;
    final link = Uri.tryParse(jsonText(json['link']).trim());
    final image = Uri.tryParse(jsonText(json['image_url']).trim());
    bool web(Uri? uri) =>
        uri != null && (uri.isScheme('https') || uri.isScheme('http'));
    return ShareKitPost(
      platform: platform,
      text: text,
      imageUrl: web(image) ? image.toString() : null,
      link: web(link) ? link : null,
    );
  }
}

/// A kit: the event, and a post per platform.
class ShareKit {
  const ShareKit({required this.event, this.posts = const []});

  final ShareKitEvent event;
  final List<ShareKitPost> posts;

  static ShareKit fromJson(Object? value, {required int eventId}) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    return ShareKit(
      event: ShareKitEvent.fromJson({'event': json['event']}) ??
          ShareKitEvent(id: eventId, name: 'Event'),
      posts: [
        for (final post in jsonObjects(json['platforms']))
          if (ShareKitPost.fromJson(post) case final p?) p,
      ],
    );
  }
}

/// Instagram's feed and story, and WhatsApp (its Status keeps no words).
bool captionFirstPlatform(String platform) =>
    platform.startsWith('instagram') ||
    platform.startsWith('whatsapp') ||
    platform == 'story';

String shareKitPlatformLabel(String platform) => switch (platform) {
      'instagram' => 'Instagram',
      'instagram_story' || 'instagram_stories' => 'Instagram Story',
      'whatsapp' => 'WhatsApp',
      'whatsapp_status' => 'WhatsApp Status',
      'linkedin' => 'LinkedIn',
      'linkedin_page' => 'LinkedIn Page',
      'facebook' => 'Facebook',
      'x' || 'twitter' => 'X',
      _ => platform.isEmpty
          ? 'Share'
          : platform[0].toUpperCase() +
              platform.substring(1).replaceAll('_', ' '),
    };

/// The emoji beside a platform's name.
String shareKitPlatformEmoji(String platform) => switch (platform) {
      final p when p.startsWith('instagram') => '📸',
      final p when p.startsWith('whatsapp') => '💬',
      final p when p.startsWith('linkedin') => '💼',
      'facebook' => '👍',
      'x' || 'twitter' => '✖️',
      _ => '🔗',
    };
