import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_feedback.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_list_footer.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_share.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/entrance.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';

/// Posts from the clubs you follow, newest first -- `/following/posts`,
/// from the Clubs tab. The website's "From the clubs" shows every club;
/// this is the follower's own feed (`/threads/feed`).
class FollowingThreadsPage extends ConsumerWidget {
  const FollowingThreadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'FROM YOUR CLUBS',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: signedIn ? const _Feed() : const _SignedOut(),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followingThreadsProvider);
    final notifier = ref.read(followingThreadsProvider.notifier);

    if (state.isLoading && state.threads.isEmpty) {
      return FadeSwitch(
        phase: ScreenPhase.loading,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (_, __) => const ShimmerThreadCard(),
        ),
      );
    }
    if (state.error != null && state.threads.isEmpty) {
      return FadeSwitch(
        phase: ScreenPhase.error,
        child: ErrorView(message: state.error, onRetry: notifier.load),
      );
    }
    return FadeSwitch(
      phase: ScreenPhase.content,
      child: RefreshIndicator(
        color: ThreadCard.ink,
        onRefresh: () async {
          final error = await notifier.refresh();
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error)));
          }
        },
        child:
            state.threads.isEmpty ? const _NothingYet() : _List(state: state),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  final ClubThreadsState state;

  const _List({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(followingThreadsProvider.notifier);
    final threads = state.threads;
    final showFooter =
        state.hasMore || state.isLoadingMore || state.loadMoreError != null;

    return EntranceScope(
      child: ListView.separated(
        key: const ValueKey('following-posts'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: threads.length + (showFooter ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          if (index == threads.length) {
            return ThreadListFooter(
                state: state, onLoadMore: notifier.loadMore);
          }
          final thread = threads[index];
          return Entrance(
            index: index,
            child: ThreadCard(
              key: ValueKey(thread.id),
              thread: thread,
              onTap: () =>
                  context.push('/threads/${Uri.encodeComponent(thread.id)}'),
              onClubTap: () => _openClub(context, thread),
              onLike: () async {
                if (!ensureSignedIn(context, ref, 'Sign in to like posts.')) {
                  return;
                }
                final failure = await notifier.toggleLike(thread.id);
                if (failure != null && context.mounted) {
                  showThreadFailure(context, ref, failure);
                }
              },
              onVote: (optionId) async {
                if (!ensureSignedIn(context, ref, 'Sign in to vote.')) return;
                final failure = await notifier.vote(thread.id, optionId);
                if (failure != null && context.mounted) {
                  showThreadFailure(context, ref, failure);
                }
              },
              onReport: () => reportContent(
                context,
                ref,
                target: ReportTarget.thread(thread.id),
                what: 'post',
              ),
              onShare: (button) => shareThread(button, ref, thread),
            ),
          );
        },
      ),
    );
  }

  void _openClub(BuildContext context, Thread thread) {
    if (thread.club.id <= 0) return;
    context.push('/clubs/${thread.club.id}', extra: {
      'clubSlug': thread.club.slug ?? '',
      'clubName': thread.club.name,
    });
  }
}

/// Follows nobody yet, or nobody has posted.
class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('following-posts-empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height / 4,
          child: const Image(image: AssetImage(AssetResources.nonotes)),
        ),
        const SizedBox(height: 16),
        const Text(
          'No posts yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'When the clubs you follow post an update or a poll, it shows up '
          'here. Follow more clubs to see more.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton(
            onPressed: () => context.push('/clubs/explore'),
            child: const Text('EXPLORE CLUBS'),
          ),
        ),
      ],
    );
  }
}

class _SignedOut extends ConsumerWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        key: const ValueKey('following-posts-signed-out'),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Your clubs, in one place',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontFamily: 'BebasNeue',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to see the posts and polls from the clubs you follow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('following-posts-sign-in'),
              onPressed: () => startSignIn(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
              ),
              child: const Text('SIGN IN'),
            ),
          ],
        ),
      ),
    );
  }
}
