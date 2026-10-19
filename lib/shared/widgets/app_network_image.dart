import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/shared/utils/image_url.dart';

export 'package:finnet/core/cache/image_caches.dart' show ImagePrivacy;

/// The largest a picture is decoded, in pixels across, whatever its slot.
/// A 4000px phone photo uploaded as a club logo decoded at full size took
/// ~60 MB of memory to draw 40 points.
const maxDecodePixels = 2048;

/// How wide to decode a picture shown [width] by [height] logical pixels.
///
/// The larger side, so a picture cropped to fill its box (`BoxFit.cover`)
/// still has the pixels for it; at the screen's [devicePixelRatio]; never
/// above [maxDecodePixels]. Null when neither side is known: the caller
/// falls back to the screen's width.
int? decodeWidthFor(double? width, double? height, double devicePixelRatio) {
  final sides = [width, height]
      .whereType<double>()
      .where((side) => side.isFinite && side > 0);
  if (sides.isEmpty) return null;
  final pixels = (sides.reduce(math.max) * devicePixelRatio).ceil();
  return math.min(pixels, maxDecodePixels);
}

/// The decode width for a picture whose box is not known: the screen's
/// width, which nothing on a phone is wider than.
int screenDecodeWidth(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media == null) return maxDecodePixels;
  return decodeWidthFor(media.size.width, null, media.devicePixelRatio) ??
      maxDecodePixels;
}

/// A picture from the network as an [ImageProvider] -- for a
/// [DecorationImage], a [CircleAvatar] -- disk-cached under its stable key
/// ([imageCacheKey]) and decoded at most [decodeWidth] pixels across.
ImageProvider appImageProvider(
  String url, {
  ImagePrivacy privacy = ImagePrivacy.public,
  int? decodeWidth,
}) {
  final provider = CachedNetworkImageProvider(
    url,
    cacheKey: imageCacheKey(url),
    cacheManager: AppImageCaches.of(privacy),
  );
  return ResizeImage.resizeIfNeeded(decodeWidth, null, provider);
}

/// A picture from the network: the one way the app shows one.
///
/// Disk-cached under a key that survives re-signing ([imageCacheKey]), in
/// the public or the private cache ([privacy]), decoded no larger than it
/// is drawn, with a placeholder while it loads and a fallback when it
/// cannot -- never an empty box, never a red error.
///
/// A null, blank or non-web [url] draws the fallback without asking the
/// network.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImagePrivacy privacy;

  /// Shown while loading. Defaults to [errorWidget], else a grey box.
  final WidgetBuilder? placeholder;

  /// Shown when there is no picture or it fails. Defaults to a grey box.
  final WidgetBuilder? errorWidget;

  /// How wide to decode, in pixels. Defaults to the box, else the screen.
  final int? decodeWidth;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.privacy = ImagePrivacy.public,
    this.placeholder,
    this.errorWidget,
    this.decodeWidth,
  });

  /// The grey box drawn when nothing better was given.
  static const fallbackKey = ValueKey('app-network-image-fallback');

  Widget _fallback(BuildContext context) =>
      errorWidget?.call(context) ??
      SizedBox(
        key: fallbackKey,
        width: width,
        height: height,
        child: const ColoredBox(color: Color(0xFFEFEFEF)),
      );

  @override
  Widget build(BuildContext context) {
    final link = url?.trim() ?? '';
    if (!isWebImageUrl(link)) return _fallback(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final decode = decodeWidth ??
        decodeWidthFor(width, height, dpr) ??
        screenDecodeWidth(context);
    return CachedNetworkImage(
      imageUrl: link,
      cacheKey: imageCacheKey(link),
      cacheManager: AppImageCaches.of(privacy),
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: decode,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, _) =>
          placeholder?.call(context) ?? _fallback(context),
      errorWidget: (context, _, __) => _fallback(context),
    );
  }
}
