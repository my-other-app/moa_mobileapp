import 'package:flutter/widgets.dart';
import 'package:finnet/shared/widgets/app_network_image.dart'
    show decodeWidthFor;
import 'package:finnet/shared/widgets/event_poster_image.dart';

/// Names the posters in one list or rail, so the poster tapped flies from
/// its card into the event's page (and back).
///
/// A tag is unique only within its scope: the same event in two rails on
/// one screen ("This week" and "Popular") gets two tags, as a hero must.
/// Cards outside any scope have no hero at all -- the safe default for a
/// list nobody has named.
class PosterHeroScope extends InheritedWidget {
  const PosterHeroScope({super.key, required this.name, required super.child});

  /// The list's own name: "this-week", "popular".
  final String name;

  /// The tag for the poster of [eventId], [index]th in the nearest scope;
  /// null outside one.
  static String? tagFor(BuildContext context, Object eventId, int index) {
    final scope = context.dependOnInheritedWidgetOfExactType<PosterHeroScope>();
    return scope == null ? null : 'poster:${scope.name}:$index:$eventId';
  }

  @override
  bool updateShouldNotify(PosterHeroScope oldWidget) => name != oldWidget.name;
}

/// What a card knew of its event's picture: enough for the event's page to
/// draw the very same poster (or drawn cover) while the event loads, so
/// the poster that flies in lands on itself.
class PosterHint {
  const PosterHint({
    this.poster,
    this.categoryId,
    this.categoryName,
    this.startsAt,
    this.isOnline = false,
    this.size,
  });

  /// The API's poster map, or a URL; null for a drawn cover.
  final Object? poster;

  /// What the drawn cover is drawn from.
  final Object? categoryId;
  final String? categoryName;
  final DateTime? startsAt;
  final bool isOnline;

  /// The poster's size on the card. Decoded as the card decoded it, it is
  /// a picture already in memory, so it shows at once.
  final Size? size;

  /// The card's picture, cropped to whatever box it is put in (as the
  /// page's own poster is): what the page shows until its own, sharper
  /// poster has loaded. Null for a drawn cover (the page draws its own),
  /// or without the card's size.
  Widget? cardPoster(Object? eventId) {
    final size = this.size;
    if (poster == null || size == null) return null;
    return Builder(
      builder: (context) => EventPosterImage(
        poster: poster,
        eventId: eventId,
        categoryId: categoryId,
        categoryName: categoryName,
        startsAt: startsAt,
        isOnline: isOnline,
        decodeWidth: decodeWidthFor(
          size.width,
          size.height,
          MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0,
        ),
      ),
    );
  }
}

/// [child] as a hero under [tag]; just [child] when there is no tag.
class PosterHero extends StatelessWidget {
  const PosterHero({super.key, required this.tag, required this.child});

  final String? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    if (tag == null) return child;
    return Hero(
      tag: tag,
      // The page's poster, sized along the way: it is the larger picture,
      // and already loaded (the card and the page use the same size).
      transitionOnUserGestures: true,
      child: child,
    );
  }
}
