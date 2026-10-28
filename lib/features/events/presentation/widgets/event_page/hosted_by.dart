import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:finnet/common/models/events/cohost_model.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// "Hosted by A and B" on a co-hosted event's page: the clubs' logos
/// overlapping, the host's first, then the sentence, in which each club's
/// name opens that club. A logo opens its club too.
///
/// The host comes in the co-hosts' own shape ([EventCohost]), so the line
/// treats every club alike.
class HostedByLine extends StatefulWidget {
  final EventCohost host;
  final List<EventCohost> cohosts;

  /// Opens a club's page; null leaves the names still.
  final ValueChanged<EventCohost>? onOpen;

  /// How big each logo is drawn.
  final double logoSize;

  const HostedByLine({
    super.key,
    required this.host,
    required this.cohosts,
    this.onOpen,
    this.logoSize = 28,
  });

  static const lineKey = ValueKey('event-hosted-by');

  /// The sentence itself.
  static const namesKey = ValueKey('event-hosted-by-names');

  @override
  State<HostedByLine> createState() => _HostedByLineState();
}

class _HostedByLineState extends State<HostedByLine> {
  /// One per club, the host's first; null for a club that can't be opened.
  List<TapGestureRecognizer?> _taps = const [];

  List<EventCohost> get _clubs => [widget.host, ...widget.cohosts];

  @override
  void initState() {
    super.initState();
    _taps = _makeTaps();
  }

  @override
  void didUpdateWidget(HostedByLine old) {
    super.didUpdateWidget(old);
    _disposeTaps();
    _taps = _makeTaps();
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  List<TapGestureRecognizer?> _makeTaps() => [
        for (final club in _clubs)
          if (widget.onOpen != null && (club.clubId > 0 || club.slug.isNotEmpty))
            (TapGestureRecognizer()..onTap = () => widget.onOpen?.call(club))
          else
            null,
      ];

  void _disposeTaps() {
    for (final tap in _taps) {
      tap?.dispose();
    }
    _taps = const [];
  }

  @override
  Widget build(BuildContext context) {
    final clubs = _clubs;
    final names = <InlineSpan>[const TextSpan(text: 'Hosted by ')];
    for (var i = 0; i < clubs.length; i++) {
      if (i > 0) {
        names.add(TextSpan(text: i == clubs.length - 1 ? ' and ' : ', '));
      }
      // Bold, and opening the club when it can be opened.
      names.add(TextSpan(
        text: clubs[i].name,
        recognizer: i < _taps.length ? _taps[i] : null,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
    }
    return Row(
      key: HostedByLine.lineKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The names say who: the logos are for the eye (and a bigger
        // place to tap).
        ExcludeSemantics(
          child: ClubLogoStack(
            clubs: clubs,
            size: widget.logoSize,
            onOpen: widget.onOpen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            key: HostedByLine.namesKey,
            TextSpan(children: names),
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

/// Clubs' logos in a row, each overlapping the one before it, the first on
/// top: on a co-hosted event, the host's and then its co-hosts'.
class ClubLogoStack extends StatelessWidget {
  final List<EventCohost> clubs;
  final double size;

  /// How much of each logo the next one covers, as a share of [size].
  final double overlap;
  final ValueChanged<EventCohost>? onOpen;

  const ClubLogoStack({
    super.key,
    required this.clubs,
    this.size = 28,
    this.overlap = 0.32,
    this.onOpen,
  });

  /// The key of the logo of the club at [index].
  static ValueKey<String> logoKey(int index) => ValueKey('club-logo-$index');

  @override
  Widget build(BuildContext context) {
    if (clubs.isEmpty) return const SizedBox.shrink();
    const ring = 2.0;
    final outer = size + ring * 2;
    final step = outer * (1 - overlap);
    final width = outer + step * (clubs.length - 1);
    return SizedBox(
      width: width,
      height: outer,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The last first, so the host's logo lies on top.
          for (var i = clubs.length - 1; i >= 0; i--)
            Positioned(
              left: step * i,
              top: 0,
              child: _Logo(
                key: logoKey(i),
                club: clubs[i],
                size: size,
                ring: ring,
                onOpen: onOpen,
              ),
            ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final EventCohost club;
  final double size;
  final double ring;
  final ValueChanged<EventCohost>? onOpen;

  const _Logo({
    super.key,
    required this.club,
    required this.size,
    required this.ring,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      width: size,
      height: size,
      color: const Color(0xFFEFEFEF),
      alignment: Alignment.center,
      child: Text(
        club.initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
    final logo = club.logo;
    final disc = Container(
      width: size + ring * 2,
      height: size + ring * 2,
      padding: EdgeInsets.all(ring),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: logo == null
            ? initials
            : AppNetworkImage(
                url: logo,
                width: size,
                height: size,
                placeholder: (_) => initials,
                errorWidget: (_) => initials,
                decodeWidth: decodeWidthFor(
                    size, size, MediaQuery.devicePixelRatioOf(context)),
              ),
      ),
    );
    final onOpen = this.onOpen;
    if (onOpen == null || (club.clubId <= 0 && club.slug.isEmpty)) {
      return disc;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpen(club),
      child: disc,
    );
  }
}
