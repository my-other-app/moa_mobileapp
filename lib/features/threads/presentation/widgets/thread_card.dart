import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/time_ago.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// A club's post, as a card: who posted and when, what they said, the photo
/// and the poll if there is one, and the like and comment counts.
///
/// Drawn in the outline style the club pages already use (the Figma frame
/// the notes cards were built to): a 1.5px ink border, 16px corners, white.
///
/// Stateless, with every action handed in, so the same card serves the
/// club's list and the post's own page -- and so it can be tested without a
/// network or a provider in sight.
class ThreadCard extends StatelessWidget {
  final Thread thread;

  /// Open the post. Null on the post's own page, where there is nowhere to
  /// go.
  final VoidCallback? onTap;

  /// Like, or take the like back.
  final VoidCallback? onLike;

  /// Vote for an option on the poll.
  final ValueChanged<String>? onVote;

  /// Open the comments. Defaults to [onTap].
  final VoidCallback? onComments;

  /// Open the club. Null where the club is already on screen.
  final VoidCallback? onClubTap;

  /// Report the post. When set, the header has a "…" menu offering it.
  final VoidCallback? onReport;

  /// Share the post's page on the website. Given the button's own context,
  /// which the share sheet points at on an iPad.
  final ValueChanged<BuildContext>? onShare;

  /// Show the whole text rather than the first few lines.
  final bool expanded;

  const ThreadCard({
    super.key,
    required this.thread,
    this.onTap,
    this.onLike,
    this.onVote,
    this.onComments,
    this.onClubTap,
    this.onReport,
    this.onShare,
    this.expanded = false,
  });

  static const ink = Color(0xFF1E1E1E);
  static const _radius = 16.0;

  /// Lines of text a card shows before it is opened.
  static const collapsedLines = 8;

  @override
  Widget build(BuildContext context) {
    final body = thread.body.trim();
    final imageUrl = thread.imageUrl;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: ink, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                thread: thread,
                onClubTap: onClubTap,
                onReport: onReport,
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  body,
                  maxLines: expanded ? null : collapsedLines,
                  overflow:
                      expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: ink,
                  ),
                ),
              ],
              if (imageUrl != null) ...[
                const SizedBox(height: 14),
                _ThreadImage(url: imageUrl),
              ],
              if (thread.hasPoll) ...[
                const SizedBox(height: 14),
                ThreadPollView(poll: thread.poll!, onVote: onVote),
              ],
              const SizedBox(height: 12),
              _Actions(
                thread: thread,
                onLike: onLike,
                onComments: onComments ?? onTap,
                onShare: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Thread thread;
  final VoidCallback? onClubTap;
  final VoidCallback? onReport;

  const _Header({required this.thread, this.onClubTap, this.onReport});

  @override
  Widget build(BuildContext context) {
    final name = thread.club.name.isEmpty ? 'Club' : thread.club.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onClubTap,
          child: ThreadClubAvatar(
            name: name,
            logoUrl: thread.club.logoUrl,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onClubTap,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ThreadCard.ink,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeAgo(thread.createdAt),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        if (thread.pinned) ...[
          const SizedBox(width: 8),
          const _PinnedChip(),
        ],
        if (onReport != null) _PostMenu(onReport: onReport!),
      ],
    );
  }
}

enum _PostAction { report }

/// The "…" in a post's header.
class _PostMenu extends StatelessWidget {
  final VoidCallback onReport;

  const _PostMenu({required this.onReport});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton<_PostAction>(
        key: const ValueKey('thread-more'),
        tooltip: 'More options',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz, color: ThreadCard.ink),
        color: Colors.white,
        onSelected: (_) => onReport(),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _PostAction.report,
            child: Text('Report post'),
          ),
        ],
      ),
    );
  }
}

/// The club's logo, or its initial on a neutral tile when there is none.
class ThreadClubAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double size;

  /// Square with rounded corners, as on the club page -- or a circle.
  final bool circle;

  const ThreadClubAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 44,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _Initial(name: name, size: size);
    final url = logoUrl;

    final image = url == null
        ? fallback
        : AppNetworkImage(
            url: url,
            width: size,
            height: size,
            // A plain tile while loading, so the row does not jump once the
            // image arrives; the initial if it never does.
            placeholder: (_) => const ColoredBox(color: Color(0xFFEFEFEF)),
            errorWidget: (_) => fallback,
          );

    return SizedBox(
      width: size,
      height: size,
      child: circle
          ? ClipOval(child: image)
          : ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;
  final double size;

  const _Initial({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return ColoredBox(
      color: const Color(0xFFEFEFEF),
      child: Center(
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _PinnedChip extends StatelessWidget {
  const _PinnedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paleYellow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ThreadCard.ink, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin, size: 12, color: ThreadCard.ink),
          SizedBox(width: 4),
          Text(
            'PINNED',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 14,
              letterSpacing: 0.5,
              color: ThreadCard.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadImage extends StatelessWidget {
  final String url;

  const _ThreadImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        // Tall photos are cropped rather than allowed to take the screen.
        constraints: const BoxConstraints(maxHeight: 420),
        child: AppNetworkImage(
          url: url,
          width: double.infinity,
          placeholder: (_) => Container(
            height: 200,
            color: Colors.grey[200],
          ),
          // A photo that will not load is left out rather than shown broken;
          // the text still says what the post is.
          errorWidget: (_) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// A poll: each option with its share of the votes as a bar, the person's
/// own choice marked, and the total underneath.
///
/// Tapping an option votes for it; tapping another later moves the vote.
class ThreadPollView extends StatelessWidget {
  final Poll poll;
  final ValueChanged<String>? onVote;

  const ThreadPollView({super.key, required this.poll, this.onVote});

  @override
  Widget build(BuildContext context) {
    final votes = poll.votes;
    final summary =
        '$votes ${votes == 1 ? 'vote' : 'votes'}${poll.hasVoted ? ' · You voted' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in poll.options) ...[
          _PollOptionTile(
            key: ValueKey('poll-option-${option.id}'),
            option: option,
            isChoice: option.id == poll.votedOptionId,
            onTap: onVote == null ? null : () => onVote!(option.id),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          summary,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  final PollOption option;
  final bool isChoice;
  final VoidCallback? onTap;

  const _PollOptionTile({
    super.key,
    required this.option,
    required this.isChoice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final share = option.share.clamp(0, 100);

    return Semantics(
      button: onTap != null,
      selected: isChoice,
      label: '${option.label}, $share percent${isChoice ? ', your vote' : ''}',
      // The tap is restated here because excluding the children's semantics
      // would otherwise take the InkWell's action with it.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isChoice ? ThreadCard.ink : const Color(0xFFAFAFAF),
            width: isChoice ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // The share bar, behind the label.
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: share / 100,
                  child: ColoredBox(
                    color: isChoice
                        ? AppColors.paleYellow
                        : const Color(0xFFEFEFEF),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    if (isChoice) ...[
                      const Icon(Icons.check_circle,
                          size: 18, color: ThreadCard.ink),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isChoice ? FontWeight.w700 : FontWeight.w500,
                          color: ThreadCard.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$share%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThreadCard.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final Thread thread;
  final VoidCallback? onLike;
  final VoidCallback? onComments;
  final ValueChanged<BuildContext>? onShare;

  const _Actions({
    required this.thread,
    this.onLike,
    this.onComments,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // A Wrap, not a Row: on a narrow phone two big counts must drop a line
    // rather than overflow.
    return Wrap(
      spacing: 12,
      children: [
        _ActionButton(
          key: const ValueKey('thread-like'),
          icon: thread.liked ? Icons.favorite : Icons.favorite_border,
          iconColor: thread.liked ? const Color(0xFFE53935) : ThreadCard.ink,
          count: thread.likes,
          semanticLabel: thread.liked ? 'Unlike' : 'Like',
          onTap: onLike,
        ),
        const SizedBox(width: 12),
        _ActionButton(
          key: const ValueKey('thread-comments'),
          icon: Icons.chat_bubble_outline,
          iconColor: ThreadCard.ink,
          count: thread.comments,
          semanticLabel: 'Comments',
          onTap: onComments,
        ),
        if (onShare != null) ...[
          const SizedBox(width: 12),
          // A Builder, so the share sheet can point at this very button.
          Builder(
            builder: (buttonContext) => Semantics(
              button: true,
              label: 'Share post',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('thread-share'),
                onTap: () => onShare!(buttonContext),
                customBorder: const StadiumBorder(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Icon(Icons.ios_share, size: 22, color: ThreadCard.ink),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A count as it fits beside an icon: 999, 1.2K, 12K, 3.4M.
String compactCount(int n) {
  String scaled(double value, String suffix) {
    final text = value < 10
        ? value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
        : value.floor().toString();
    return '$text$suffix';
  }

  if (n < 1000) return '$n';
  if (n < 1000000) return scaled(n / 1000, 'K');
  return scaled(n / 1000000, 'M');
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$semanticLabel, $count',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          // The padding is the tap target: a 22px icon alone is below the
          // 44px minimum.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 6),
              Text(
                compactCount(count),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ThreadCard.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
