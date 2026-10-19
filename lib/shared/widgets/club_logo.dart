import 'package:flutter/material.dart';

import 'package:finnet/shared/widgets/app_network_image.dart';

/// A club's logo, or a plain placeholder tile when it has none or the image
/// will not load.
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

  const ClubLogo({
    super.key,
    required this.url,
    this.size = 40,
    this.circle = false,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      key: const ValueKey('club-logo-placeholder'),
      width: size,
      height: size,
      color: const Color(0xFFEFEFEF),
      alignment: Alignment.center,
      child: Icon(Icons.groups_outlined, size: size * 0.5, color: Colors.grey),
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
          );

    return SizedBox(
      width: size,
      height: size,
      child: circle
          ? ClipOval(child: image)
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: image,
            ),
    );
  }
}
