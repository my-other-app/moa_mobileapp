import 'package:flutter/material.dart';

import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/picture_shape.dart';

/// A club's (or a partner's) logo, or a placeholder tile when it has none or
/// the image will not load.
///
/// Logos are square: clubs are asked for 1080 x 1080, like an Instagram
/// profile picture, and a logo is shown in a square (or a circle) in the
/// app as on the website and the dashboards. A square logo fills its frame;
/// any other shape (a wordmark, far wider than tall) is shown whole, with
/// room around it, never cropped -- a circle cut through a wordmark's
/// letters read "BOTIC" for "ROBOTICS CLUB". Either way it sits on a white
/// tile: most logos are made for white, and a transparent one stays legible.
///
/// Replaces two habits that broke on clubs without a logo: indexing the logo
/// map straight (`club['logo']['thumbnail']`, which throws on null) and
/// falling back to a random stock photo from picsum.photos, which showed
/// strangers' pictures as a club's logo.
class ClubLogo extends StatelessWidget {
  /// The image URL; null or empty draws the placeholder.
  final String? url;
  final double size;

  /// A circle rather than a rounded square.
  final bool circle;
  final double radius;

  /// Drawn when there is no logo or it will not load: a grey tile with a
  /// group icon unless given (a partner's initials, say).
  final Widget? fallback;

  const ClubLogo({
    super.key,
    required this.url,
    this.size = 40,
    this.circle = false,
    this.radius = 6,
    this.fallback,
  });

  /// The white tile behind a logo.
  static const tile = Colors.white;

  /// The line round a logo's tile.
  static const hairline = BorderSide(color: Color(0x1F000000), width: 0.5);

  /// How close to square a logo must be to fill its frame.
  static const tolerance = 0.03;

  /// The logo itself, once loaded.
  static const pictureKey = ValueKey('club-logo-picture');

  /// Whether a logo [picture] that size fills its square.
  static bool isSquare(Size picture) {
    if (picture.width <= 0 || picture.height <= 0) return false;
    return (picture.width / picture.height - 1).abs() <= tolerance;
  }

  /// The room left around a logo that is not square, each side, in a frame
  /// [size] across: more in a circle, whose edge cuts the corners of the
  /// square a wordmark is fitted in.
  static double paddingFor(double size, {required bool circle}) =>
      size * (circle ? 0.16 : 0.10);

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ??
        Container(
          key: const ValueKey('club-logo-placeholder'),
          width: size,
          height: size,
          color: const Color(0xFFEFEFEF),
          alignment: Alignment.center,
          child:
              Icon(Icons.groups_outlined, size: size * 0.5, color: Colors.grey),
        );
    final link = url?.trim() ?? '';

    final image = link.isEmpty
        ? placeholder
        : AppNetworkImage(
            url: link,
            width: size,
            height: size,
            // Plain grey while it loads; the placeholder's icon is for a
            // club that has no logo, or one that will not load.
            placeholder: (_) => const ColoredBox(color: Color(0xFFEFEFEF)),
            errorWidget: (_) => placeholder,
            imageBuilder: (_, picture) => LogoPicture(
              image: picture,
              padding: paddingFor(size, circle: circle),
            ),
          );

    final clipped = circle
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
    return SizedBox(
      width: size,
      height: size,
      // A hairline round a logo, so its white tile keeps its shape on a
      // white card.
      child: link.isEmpty
          ? clipped
          : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: circle
                    ? const CircleBorder(side: hairline)
                    : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius),
                        side: hairline,
                      ),
              ),
              child: clipped,
            ),
    );
  }
}

/// A loaded logo on its white tile: filling it when square, else whole
/// with [padding] around it.
class LogoPicture extends StatelessWidget {
  const LogoPicture({super.key, required this.image, required this.padding});

  final ImageProvider image;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return PictureShape(
      image: image,
      builder: (context, size) {
        // Until its size is known, whole: never a crop.
        final fills = size != null && ClubLogo.isSquare(size);
        final picture = Image(
          key: ClubLogo.pictureKey,
          image: image,
          fit: fills ? BoxFit.cover : BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        );
        return ColoredBox(
          color: ClubLogo.tile,
          child: fills
              ? picture
              : Padding(padding: EdgeInsets.all(padding), child: picture),
        );
      },
    );
  }
}
