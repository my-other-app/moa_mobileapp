import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

// The emoji every interest and topic is drawn with.
//
// The server's own emoji comes first. Production sent its topics with
// emoji and its 45 interests with none, so the app carries the default
// tree's emoji itself, keyed by slug. The backend's data migration gives
// the interests these same emoji, so the app and the server agree whichever
// one an interest's emoji comes from.

/// The default tree's interests, by slug.
const Map<String, String> interestEmojiBySlug = {
  // Development
  'web-development': '🌐',
  'app-development': '📱',
  'software-engineering': '🧑‍💻',
  'coding': '⌨️',
  'open-source': '🧩',
  'cloud-devops': '☁️',
  'cybersecurity': '🔐',
  'data-science': '📊',
  // Deep Tech
  'artificial-intelligence': '🦾',
  'robotics': '🤖',
  'iot-hardware': '🔌',
  'blockchain': '⛓️',
  'vr-ar': '🥽',
  'quantum-computing': '⚛️',
  'space-exploration': '🚀',
  // Design
  'ui-ux': '🎨',
  'graphic-design': '🖌️',
  'product-design': '📐',
  'animation': '🐰',
  // Arts
  'drawing': '✏️',
  'music': '🥁',
  'singing': '🎤',
  'dance': '💃',
  'theatre': '🎭',
  'photography': '📷',
  'film': '🎬',
  'writing': '📝',
  'fashion': '👗',
  // Business
  'entrepreneurship': '👨‍💼',
  'product-management': '🏭',
  'marketing': '🏷️',
  'finance': '💸',
  'analytics': '📉',
  // Gaming & Media
  'gaming': '🎮',
  'e-sports': '🏆',
  'content-creation': '🎥',
  'memes-internet-culture': '😂',
  // Community
  'volunteering': '🙌',
  'sustainability': '🌱',
  'public-speaking': '🎙️',
  'debate-mun': '🗣️',
  'quizzing': '🧠',
  // Sports & Fitness
  'sports': '🏅',
  'fitness': '💪',
  'outdoors-adventure': '🏕️',
};

/// The default tree's topics, by slug -- the emoji the server sends them
/// with.
const Map<String, String> topicEmojiBySlug = {
  'development': '💻',
  'deep-tech': '🔬',
  'design': '🎨',
  'arts': '🎭',
  'business': '💼',
  'gaming-media': '🎮',
  'community': '🤝',
  'sports-fitness': '⚽',
};

/// The emoji the server sent, when it is one to draw: only an icon the
/// server calls an emoji (`icon_type: "emoji"`) and that looks like one.
///
/// Anything else is no emoji: a URL (`icon_type: "url"`), no type at all,
/// or text -- production's first topic had the placeholder icon "string",
/// which must never appear as a word on a chip.
String? sentEmoji(String? icon, String? iconType) {
  if (iconType != 'emoji') return null;
  final text = icon?.trim() ?? '';
  if (text.isEmpty || text.runes.length > 8) return null;
  // Letters, digits or URL punctuation: a word or a link, not an emoji.
  if (RegExp(r'[A-Za-z0-9/.:]').hasMatch(text)) return null;
  // At least one symbol from the emoji and pictograph ranges.
  return text.runes.any((r) => r >= 0x2000) ? text : null;
}

/// The emoji in [table] for [slug], or for [name] made into a slug when
/// the payload carried none ("Cloud & DevOps" is `cloud-devops`).
String? _bySlug(Map<String, String> table, String? slug, String name) {
  final key = slug?.trim().toLowerCase() ?? '';
  return table[key] ?? table[slugify(name)];
}

/// An interest's emoji: the server's, else the default tree's for its slug
/// or name. Null for an interest the app does not know and the server sent
/// no emoji for.
String? interestEmoji({
  String? icon,
  String? iconType,
  String? slug,
  String name = '',
}) =>
    sentEmoji(icon, iconType) ?? _bySlug(interestEmojiBySlug, slug, name);

/// A topic's emoji: the server's, else the default tree's for its slug or
/// name. Null for a topic the app does not know and the server sent no
/// emoji for.
String? topicEmoji({
  String? icon,
  String? iconType,
  String? slug,
  String name = '',
}) =>
    sentEmoji(icon, iconType) ?? _bySlug(topicEmojiBySlug, slug, name);

extension InterestEmoji on Interest {
  /// See [interestEmoji].
  String? get emoji =>
      interestEmoji(icon: icon, iconType: iconType, slug: slug, name: name);
}

extension TopicEmoji on Topic {
  /// See [topicEmoji].
  String? get emoji =>
      topicEmoji(icon: icon, iconType: iconType, slug: slug, name: name);
}
