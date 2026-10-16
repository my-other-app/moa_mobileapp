import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:finnet/shared/widgets/event_cover.dart';

/// Where a poster is shown, which decides which of its sizes to fetch.
enum PosterSlot {
  /// A card in a feed: the 500px `medium` is plenty.
  card,

  /// The top of the event page: the sharpest there is.
  hero,

  /// A small square in a list row, e.g. a search result.
  thumb,
}

/// The poster sizes to try for each slot, best first. The server makes
/// `thumbnail` (150px), `medium` (500px) and `large` (800px) from the
/// `original` upload (`app/api/events/models.py`).
const Map<PosterSlot, List<String>> posterSizePreference = {
  PosterSlot.card: ['medium', 'large', 'original', 'thumbnail'],
  PosterSlot.hero: ['large', 'original', 'medium', 'thumbnail'],
  PosterSlot.thumb: ['thumbnail', 'medium', 'large', 'original'],
};

/// The URL to show for [poster] in [slot], or null when there is none.
///
/// [poster] is the API's poster map (`{thumbnail, medium, large,
/// original}`) or a single URL. Blank or non-web values do not count.
String? pickPosterUrl(Object? poster, {PosterSlot slot = PosterSlot.card}) {
  if (poster is String) return _usableUrl(poster);
  if (poster is Map) {
    for (final size in posterSizePreference[slot]!) {
      final url = _usableUrl(poster[size]);
      if (url != null) return url;
    }
  }
  return null;
}

String? _usableUrl(Object? value) {
  if (value is! String) return null;
  final url = value.trim();
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  if (uri.host.isEmpty) return null;
  return url;
}

/// The key a poster is cached under: its URL without the query string.
///
/// Posters are presigned S3 links that are re-signed on every API call, so
/// the full URL is new every time and a cache keyed on it never hits --
/// every scroll downloaded every poster again. The path is the S3 object,
/// which is a fresh uuid per upload, so it is stable for one image and
/// changes when the poster does.
String posterCacheKey(String url) {
  var end = url.length;
  final query = url.indexOf('?');
  if (query >= 0) end = query;
  final fragment = url.indexOf('#');
  if (fragment >= 0 && fragment < end) end = fragment;
  return url.substring(0, end);
}

/// An event's poster, or the drawn cover when there is none.
///
/// The one widget for showing an event's picture anywhere in the app. The
/// drawn cover ([EventCover]) is shown when the event has no poster, while
/// the poster loads, and if it fails to -- never an empty box, never a
/// third-party placeholder image.
class EventPosterImage extends StatelessWidget {
  /// The API's poster map (`{thumbnail, medium, large, original}`), or a
  /// single URL. Null or empty draws the cover.
  final Object? poster;

  /// The event's id, which picks the cover's look.
  final Object? eventId;

  /// The category's id, for the cover's shape.
  final Object? categoryId;

  /// The category's name, for the cover's tag.
  final String? categoryName;

  /// When the event starts, for the cover's date.
  final DateTime? startsAt;

  /// Labels the cover "Online" when there is no category.
  final bool isOnline;

  /// Which poster size to prefer; see [posterSizePreference].
  final PosterSlot slot;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Shown on the cover while the poster loads.
  static const loadingKey = ValueKey('event-poster-loading');

  /// Shown on the cover when the poster fails.
  static const fallbackKey = ValueKey('event-poster-fallback');

  const EventPosterImage({
    super.key,
    this.poster,
    required this.eventId,
    this.categoryId,
    this.categoryName,
    this.startsAt,
    this.isOnline = false,
    this.slot = PosterSlot.card,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  /// From an event as the API sends it (`id`, `poster`, `category`,
  /// `event_datetime`, `is_online`).
  factory EventPosterImage.fromEvent(
    Map<dynamic, dynamic> event, {
    Key? key,
    PosterSlot slot = PosterSlot.card,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    final category = event['category'];
    return EventPosterImage(
      key: key,
      poster: event['poster'],
      eventId: event['id'],
      categoryId: category is Map ? category['id'] : null,
      categoryName: category is Map ? category['name']?.toString() : null,
      startsAt: parseEventStart(event['event_datetime']),
      isOnline: event['is_online'] == true,
      slot: slot,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  /// The URL this will load, or null when it draws the cover.
  String? get url => pickPosterUrl(poster, slot: slot);

  EventCover _cover(Key? key) => EventCover(
        key: key,
        eventId: eventId,
        categoryId: categoryId,
        categoryName: categoryName,
        startsAt: startsAt,
        isOnline: isOnline,
      );

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    Widget child = url == null
        ? _cover(null)
        : CachedNetworkImage(
            imageUrl: url,
            cacheKey: posterCacheKey(url),
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholder: (_, __) => _cover(loadingKey),
            errorWidget: (_, __, ___) => _cover(fallbackKey),
          );
    child = SizedBox(width: width, height: height, child: child);
    final radius = borderRadius;
    if (radius != null) {
      child = ClipRRect(borderRadius: radius, child: child);
    }
    return child;
  }
}
