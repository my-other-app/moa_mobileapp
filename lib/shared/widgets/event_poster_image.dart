import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/app_network_image.dart'
    show decodeWidthFor, screenDecodeWidth;
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
/// `original` upload (`app/api/events/models.py`). A card is about 360pt
/// wide, over 1000px on a 3x phone, so `medium` would be blown up and soft.
const Map<PosterSlot, List<String>> posterSizePreference = {
  PosterSlot.card: ['large', 'medium', 'original', 'thumbnail'],
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

/// The key a poster is cached under: [imageCacheKey], which every picture
/// in the app now uses. Kept under this name for the callers that had it.
String posterCacheKey(String url) => imageCacheKey(url);

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

  /// Shown while the poster loads, in place of the drawn cover: the same
  /// poster as a card already drew it, so a page opened from that card
  /// never flashes the cover first.
  final Widget? placeholder;

  /// Decode at this many pixels across rather than at the size drawn: to
  /// draw a picture another screen has already decoded, at once.
  final int? decodeWidth;

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
    this.placeholder,
    this.decodeWidth,
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
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    Widget child = url == null
        ? _cover(null)
        : CachedNetworkImage(
            imageUrl: url,
            cacheKey: posterCacheKey(url),
            cacheManager: AppImageCaches.public,
            width: width,
            height: height,
            fit: fit,
            // Decoded at the size it is drawn, not the upload's: a card is
            // ~360pt wide, and an original can be a 4000px phone photo.
            memCacheWidth: decodeWidth ??
                decodeWidthFor(width, height, dpr) ??
                screenDecodeWidth(context),
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholder: (_, __) => placeholder == null
                ? _cover(loadingKey)
                : KeyedSubtree(key: loadingKey, child: placeholder!),
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
