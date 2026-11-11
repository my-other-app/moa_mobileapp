import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_people.dart'
    show PersonAvatar;
import 'package:finnet/features/speakers/data/speakers_api.dart';
import 'package:finnet/features/speakers/domain/speaker.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// Profile > Speakers I Follow (`/profile/speakers`): the speakers the
/// person follows, newest first, each opening their page -- where Follow
/// is, so unfollowing is done there and this list follows.
class FollowedSpeakersPage extends ConsumerWidget {
  const FollowedSpeakersPage({super.key});

  static const emptyKey = ValueKey('followed-speakers-empty');
  static const unavailableKey = ValueKey('followed-speakers-unavailable');

  static ValueKey<String> rowKey(String slug) =>
      ValueKey('followed-speaker-$slug');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedSpeakersProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SPEAKERS I FOLLOW',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: followed.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load the speakers you follow."),
          onRetry: () => ref.invalidate(followedSpeakersProvider),
        ),
        data: (speakers) => switch (speakers) {
          null => const _Note(
              key: unavailableKey,
              title: "This list isn't available right now",
              body: 'Try again later. Speakers you follow still show on '
                  'their own pages.',
            ),
          [] => const _Note(
              key: emptyKey,
              title: "You don't follow any speakers yet",
              body: "Tap a speaker on an event's page and choose Follow. "
                  "We'll tell you when they're speaking next.",
            ),
          final list => RefreshIndicator(
              color: AppColors.ink,
              onRefresh: () => ref.refresh(followedSpeakersProvider.future),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 0, indent: 16, endIndent: 16),
                itemBuilder: (context, i) => _Row(speaker: list[i]),
              ),
            ),
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.speaker});

  final FollowedSpeaker speaker;

  @override
  Widget build(BuildContext context) {
    final upcoming = switch (speaker.upcomingCount) {
      0 => null,
      1 => '1 upcoming talk',
      final n => '$n upcoming talks',
    };
    return ListTile(
      key: FollowedSpeakersPage.rowKey(speaker.slug),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: PersonAvatar(
        person: EventPerson(name: speaker.name, photo: speaker.photo),
        size: 48,
      ),
      title: Text(speaker.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: speaker.headline == null && upcoming == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (speaker.headline != null)
                  Text(speaker.headline!,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                if (upcoming != null)
                  Text(upcoming,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(speakerRoute(speaker.slug)),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎤', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
