import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/speakers/data/speakers_api.dart';
import 'package:finnet/features/speakers/domain/speaker.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/detail_sheet.dart' show personLinkIcon;
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/widgets/swap_label.dart';
import 'package:finnet/shared/widgets/toast.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// A speaker's page, by slug: the profile, or -- for a merged one -- the
/// profile it was merged into (one hop). Read again when the person signs
/// in or out: "following" is theirs.
final speakerPageProvider = FutureProvider.autoDispose
    .family<SpeakerLookup, String>((ref, slug) async {
  ref.watch(isAuthenticatedProvider);
  final api = ref.watch(speakersApiProvider);
  final first = await api.profile(slug);
  if (first is SpeakerMoved) {
    final next = await api.profile(first.slug);
    return next is SpeakerMoved ? const SpeakerMissing() : next;
  }
  return first;
});

/// `/speakers/{slug}` (the website's address too): a speaker's photo,
/// headline, bio and links, their upcoming and past talks -- each opening
/// its event -- and Follow, for a signed-in person (feature-register
/// `speakers-contract.md`). Open without an account; following asks for
/// one.
class SpeakerPage extends ConsumerStatefulWidget {
  const SpeakerPage({super.key, required this.slug});

  final String slug;

  static const followKey = ValueKey('speaker-follow');
  static const missingKey = ValueKey('speaker-missing');
  static const upcomingKey = ValueKey('speaker-upcoming');
  static const pastKey = ValueKey('speaker-past');

  @override
  ConsumerState<SpeakerPage> createState() => _SpeakerPageState();
}

class _SpeakerPageState extends ConsumerState<SpeakerPage> {
  /// The person's own choice since the page was read, over the page's.
  bool? _following;
  int? _followers;
  bool _busy = false;

  Future<void> _toggle(SpeakerProfile profile) async {
    final here = speakerRoute(widget.slug);
    if (!ensureSignedIn(context, ref, 'Sign in to follow speakers and hear '
        'when they are speaking next.', returnTo: here)) {
      return;
    }
    if (_busy) return;
    final was = _following ?? profile.following;
    final count = _followers ?? profile.followersCount;
    setState(() {
      _busy = true;
      _following = !was;
      _followers = was ? (count > 0 ? count - 1 : 0) : count + 1;
    });
    try {
      final api = ref.read(speakersApiProvider);
      final answer = was
          ? await api.unfollow(profile.slug)
          : await api.follow(profile.slug);
      if (!mounted) return;
      // Profile > Speakers I Follow, should it be open beneath this page.
      ref.invalidate(followedSpeakersProvider);
      // The server's count, when it gives one: others follow too.
      setState(() {
        _busy = false;
        if (answer != null) {
          _following = answer.following;
          _followers = answer.followersCount ?? _followers;
        }
      });
      if (!was) {
        showToast(context,
            "You're following ${profile.name}. We'll tell you when they speak.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _following = was;
        _followers = count;
      });
      showToast(
        context,
        extractErrorMessage(e,
            defaultMessage: was
                ? "Couldn't unfollow. Try again."
                : "Couldn't follow. Try again."),
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(speakerPageProvider(widget.slug));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SPEAKER',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: lookup.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load this speaker."),
          onRetry: () => ref.invalidate(speakerPageProvider(widget.slug)),
        ),
        data: (found) => switch (found) {
          SpeakerFound(:final profile) => _profile(context, profile),
          _ => _Missing(slug: widget.slug),
        },
      ),
    );
  }

  Widget _profile(BuildContext context, SpeakerProfile profile) {
    final following = _following ?? profile.following;
    final followers = _followers ?? profile.followersCount;
    final photo = profile.photo;
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () async {
        setState(() {
          _following = null;
          _followers = null;
        });
        final fresh = ref.refresh(speakerPageProvider(widget.slug).future);
        await fresh;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFFEDEFF2),
              foregroundImage: photo == null
                  ? null
                  : appImageProvider(photo,
                      decodeWidth: decodeWidthFor(
                          104, 104, MediaQuery.devicePixelRatioOf(context))),
              onForegroundImageError: photo == null ? null : (_, __) {},
              child: Text(
                profile.initials,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          if (profile.headline != null) ...[
            const SizedBox(height: 4),
            Text(
              profile.headline!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if (profile.city != null) profile.city!,
              followers == 1
                  ? '1 follower'
                  : '${NumberFormat.decimalPattern('en_IN').format(followers)} '
                      'followers',
            ].join(' · '),
            key: const ValueKey('speaker-followers'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          Pressable(
            child: FilledButton(
              key: SpeakerPage.followKey,
              onPressed: () => _toggle(profile),
              style: FilledButton.styleFrom(
                backgroundColor: following ? Colors.white : AppColors.ink,
                foregroundColor: following ? AppColors.ink : Colors.white,
                side: const BorderSide(color: AppColors.ink),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: SwapLabel(
                following ? 'UNFOLLOW' : 'FOLLOW',
                style: const TextStyle(fontSize: 22, fontFamily: 'BebasNeue'),
              ),
            ),
          ),
          if (profile.bio != null) ...[
            const SizedBox(height: 20),
            SelectableText(
              profile.bio!,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
          if (profile.links.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in profile.links) _LinkButton(link: link),
              ],
            ),
          ],
          if (profile.topics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final topic in profile.topics)
                  Chip(
                    label: Text(topic, style: const TextStyle(fontSize: 13)),
                    backgroundColor: AppColors.softGrey,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (profile.upcoming.isNotEmpty)
            _Talks(
                key: SpeakerPage.upcomingKey,
                title: 'UPCOMING TALKS',
                talks: profile.upcoming),
          if (profile.past.isNotEmpty)
            _Talks(
                key: SpeakerPage.pastKey,
                title: 'PAST TALKS',
                talks: profile.past),
          if (profile.upcoming.isEmpty && profile.past.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'No talks listed yet. Follow to hear when there is one.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkButton extends ConsumerWidget {
  const _LinkButton({required this.link});

  final PersonLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: ValueKey('speaker-link-${link.kind.name}'),
      onPressed: () async {
        final opened = await ref.read(linkLauncherProvider)(link.uri);
        if (!opened && context.mounted) {
          showToast(context, "Couldn't open that link",
              icon: Icons.error_outline);
        }
      },
      icon: Icon(personLinkIcon(link.kind), size: 18),
      label: Text(link.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _Talks extends StatelessWidget {
  const _Talks({super.key, required this.title, required this.talks});

  final String title;
  final List<SpeakerTalk> talks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontFamily: 'BebasNeue', fontSize: 22)),
          const SizedBox(height: 8),
          for (final talk in talks) _TalkTile(talk: talk),
        ],
      ),
    );
  }
}

class _TalkTile extends StatelessWidget {
  const _TalkTile({required this.talk});

  final SpeakerTalk talk;

  @override
  Widget build(BuildContext context) {
    final date = talk.date;
    final line = [
      if (date != null) DateFormat('EEE, d MMM yyyy').format(date),
      if (talk.clubName != null) talk.clubName!,
    ].join(' · ');
    return InkWell(
      key: ValueKey('speaker-talk-${talk.eventId}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push(talk.eventRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                url: talk.poster,
                width: 56,
                height: 70,
                errorWidget: (_) => Container(
                  width: 56,
                  height: 70,
                  color: AppColors.softGrey,
                  alignment: Alignment.center,
                  child: const Text('🎤', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(talk.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (talk.talkTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('“${talk.talkTitle}”',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontStyle: FontStyle.italic)),
                    ),
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(line,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

/// Hidden, removed, never there -- or a server without speaker pages yet:
/// said plainly, with the website's page as a way on.
class _Missing extends ConsumerWidget {
  const _Missing({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      key: SpeakerPage.missingKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎤', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text("This speaker's page isn't available",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Their talks are still on the events’ pages.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              key: const ValueKey('speaker-open-website'),
              onPressed: () => ref.read(linkLauncherProvider)(
                  websiteUriFor(speakerRoute(slug))),
              child: const Text('OPEN ON THE WEBSITE'),
            ),
          ],
        ),
      ),
    );
  }
}
