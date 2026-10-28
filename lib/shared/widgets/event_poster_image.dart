import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/app_network_image.dart'
    show decodeWidthFor, screenDecodeWidth;
import 'package:finnet/shared/widgets/event_cover.dart';
import 'package:finnet/shared/widgets/picture_shape.dart';

/// A poster's shape: 4:5, portrait, as clubs are asked to upload it
/// (1080 x 1350, an Instagram portrait post). Every frame a poster is shown
/// in has this shape, in the app as on the website and the dashboards.
const double posterAspectRatio = 4 / 5;

/// Where a poster is shown, which decides which of its sizes to fetch.
///
/// Each slot asks first for the smallest size at least twice as wide as
/// it is drawn, so a poster is sharp on a 3x phone.
enum PosterSlot {
  /// A card: a feed card, a discover card, a rail's card (about 170 to
  /// 360 points wide).
  card,

  /// The top of the event page, as wide as the screen: the sharpest there is.
  hero,

  /// A small poster in a list row (up to 120 points wide), e.g. a search
  /// result.
  thumb,
}

/// The poster sizes to try for each slot, best first. The server fits
/// each size inside a 4:5 box (`app/core/storage/shapes.py`): `thumbnail`
/// 240 x 300, `medium` 540 x 675, `large` 1080 x 1350, never enlarged, and
/// keeps the `original` (posters uploaded before Oct 2026 have smaller
/// sizes: 150, 500 and 800 square boxes).
///
/// - A card is up to ~360pt wide, over 1000px on a 3x phone: `large`,
///   else the `original`; `medium` would be blown up and soft.
/// - The event page is the screen's width: the `original` first (an old
///   poster's `large` is only 640px across), else `large`.
/// - A row's thumb is under 120pt: the `thumbnail`.
const Map<PosterSlot, List<String>> posterSizePreference = {
  PosterSlot.card: ['large', 'original', 'medium', 'thumbnail'],
  PosterSlot.hero: ['original', 'large', 'medium', 'thumbnail'],
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

  /// The frame. A poster's frame is 4:5 ([posterAspectRatio]): give both
  /// sides in that shape, or neither and put it in an [AspectRatio].
  final double? width;
  final double? height;
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
    // Decoded at the size it is drawn, not the upload's: a card is ~360pt
    // wide, and an original can be a 4000px phone photo.
    final decode = decodeWidth ??
        decodeWidthFor(width, height, dpr) ??
        screenDecodeWidth(context);
    Widget child = url == null
        ? _cover(null)
        : CachedNetworkImage(
            imageUrl: url,
            cacheKey: posterCacheKey(url),
            cacheManager: AppImageCaches.public,
            width: width,
            height: height,
            memCacheWidth: decode,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 100),
            // The image builder is handed the full-size provider; resized
            // as the widget resized it, it is the picture already decoded.
            imageBuilder: (_, image) => PosterPicture(
              image: ResizeImage.resizeIfNeeded(decode, null, image),
            ),
            placeholder: (_, __) => placeholder == null
                ? _cover(loadingKey)
                : KeyedSubtree(key: loadingKey, child: placeholder!),
            errorWidget: (_, __, ___) => _cover(fallbackKey),
          );
    child = SizedBox(width: width, height: height, child: child);
    // The blurred copy behind a poster is larger than the frame: clipped,
    // with or without rounded corners.
    final radius = borderRadius;
    return radius != null
        ? ClipRRect(borderRadius: radius, child: child)
        : ClipRect(child: child);
  }
}

/// A poster, whole, in whatever frame it is given: never cropped.
///
/// Posters carry their text to the edges, so the picture is fitted inside
/// the frame (`BoxFit.contain`) and the space around a poster of another
/// shape is filled by a soft, blurred copy of itself. A poster already the
/// frame's shape (within 1%) fills it, and nothing is blurred: no blur to
/// draw in a scrolling list for the posters made to size. Both layers are
/// the same picture -- one download, one decode.
class PosterPicture extends StatelessWidget {
  const PosterPicture({super.key, required this.image});

  /// The loaded poster (CachedNetworkImage's imageBuilder hands it over).
  final ImageProvider image;

  /// The blurred copy, present only when the poster is not the frame's shape.
  static const backdropKey = ValueKey('poster-backdrop');

  /// The poster itself, whole.
  static const pictureKey = ValueKey('poster-picture');

  /// How close a poster's shape must be to its frame's to fill it.
  static const tolerance = 0.01;

  /// Whether a [picture] of that size fills a frame of [frameAspect]
  /// (width / height) without a backdrop.
  static bool fits(Size picture, double frameAspect) {
    if (picture.width <= 0 || picture.height <= 0 || frameAspect <= 0) {
      return false;
    }
    return ((picture.width / picture.height) / frameAspect - 1).abs() <=
        tolerance;
  }

  /// The blur's strength for a frame [width] points wide: softer in a
  /// small thumb, where a strong blur would be a flat wash.
  static double blurFor(double width) => width.isFinite && width < 100 ? 6 : 16;

  @override
  Widget build(BuildContext context) {
    // The poster's own size: known before the first build, as it is loaded.
    return PictureShape(
      image: image,
      builder: (context, size) => LayoutBuilder(builder: (context, box) {
        final bounded = box.hasBoundedWidth &&
            box.hasBoundedHeight &&
            box.maxWidth > 0 &&
            box.maxHeight > 0;
        final frame =
            bounded ? box.maxWidth / box.maxHeight : posterAspectRatio;
        final fits = size != null && PosterPicture.fits(size, frame);
        final sigma = PosterPicture.blurFor(box.maxWidth);
        // Behind the poster: the poster again, filling the frame -- blurred
        // and very slightly dimmed around a poster of another shape; as it is
        // under one that fits, only to cover a sub-pixel seam.
        final fill = Transform.scale(
          scale: fits ? 1 : 1.15,
          child: Image(
            image: image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            if (fits)
              fill
            else ...[
              RepaintBoundary(
                child: ImageFiltered(
                  key: PosterPicture.backdropKey,
                  imageFilter:
                      ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: fill,
                ),
              ),
              const ColoredBox(color: Color(0x14000000)),
            ],
            Image(
              key: PosterPicture.pictureKey,
              image: image,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ],
        );
      }),
    );
  }
}
