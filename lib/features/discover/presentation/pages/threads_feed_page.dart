import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_feedback.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/entrance.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';

/// "From the clubs": the newest posts and polls from every club, newest
/// first -- the website's `/threads`. The club's own THREADS tab's card and
/// post page; liking and voting ask a signed-out reader to sign in.
class ThreadsFeedPage extends ConsumerWidget {
  const ThreadsFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverThreadsProvider);
    final notifier = ref.read(discoverThreadsProvider.notifier);

    Widget body;
    final ScreenPhase phase;
    if (state.isLoading && state.items.isEmpty) {
      phase = ScreenPhase.loading;
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (_, __) => const ShimmerThreadCard(),
      );
    } else if (state.error != null && state.items.isEmpty) {
      phase = ScreenPhase.error;
      body = ErrorView(message: state.error, onRetry: notifier.load);
    } else if (state.items.isEmpty) {
      phase = ScreenPhase.empty;
      body = ListView(
        children: [
          DiscoverEmpty(
            key: const ValueKey('discover-threads-empty'),
            icon: Icons.forum_outlined,
            title: 'No posts yet',
            message:
                'When clubs post news, photos and polls, they show up here.',
            actionLabel: 'Browse clubs',
            onAction: () => context.push(clubsDirectoryLocation()),
          ),
        ],
      );
    } else {
      phase = ScreenPhase.content;
      body = RefreshIndicator(
        color: ThreadCard.ink,
        onRefresh: notifier.refresh,
        child: EntranceScope(
          child: ListView.separated(
            key: const ValueKey('discover-threads-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: state.items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, i) {
              if (i == state.items.length) {
                return PagedFooter(
                    state: state, onLoadMore: notifier.loadMore, noun: 'posts');
              }
              final thread = state.items[i];
              return Entrance(
                index: i,
                child: ThreadCard(
                  key: ValueKey(thread.id),
                  thread: thread,
                  onTap: () => _open(context, ref, thread),
                  onClubTap: () => openDiscoverClub(
                    context,
                    id: thread.club.id,
                    slug: thread.club.slug,
                    name: thread.club.name,
                  ),
                  onLike: () => _like(context, ref, thread),
                  onVote: (option) => _vote(context, ref, thread, option),
                  onReport: () => reportContent(
                    context,
                    ref,
                    target: ReportTarget.thread(thread.id),
                    what: 'post',
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'FROM THE CLUBS',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: FadeSwitch(phase: phase, child: body),
    );
  }

  /// The post's page; back from it, the card is read again.
  Future<void> _open(BuildContext context, WidgetRef ref, Thread thread) async {
    final notifier = ref.read(discoverThreadsProvider.notifier);
    await context.push('/threads/${Uri.encodeComponent(thread.id)}');
    await notifier.reread(thread.id);
  }

  Future<void> _like(BuildContext context, WidgetRef ref, Thread thread) async {
    if (!ensureSignedIn(context, ref, 'Sign in to like posts.')) return;
    final failure =
        await ref.read(discoverThreadsProvider.notifier).toggleLike(thread.id);
    if (failure != null && context.mounted) {
      showThreadFailure(context, ref, failure);
    }
  }

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    Thread thread,
    String optionId,
  ) async {
    if (!ensureSignedIn(context, ref, 'Sign in to vote.')) return;
    final failure = await ref
        .read(discoverThreadsProvider.notifier)
        .vote(thread.id, optionId);
    if (failure != null && context.mounted) {
      showThreadFailure(context, ref, failure);
    }
  }
}
