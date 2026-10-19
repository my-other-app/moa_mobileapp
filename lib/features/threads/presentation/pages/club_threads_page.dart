import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/resources/asset_resources.dart';
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

/// The THREADS tab on a club's page: what the club has posted, pinned first
/// then newest, a page at a time.
///
/// Replaces the NOTES tab. Clubs stopped writing notes when Threads arrived
/// on their dashboard, so the old tab could only ever show an archive.
class ClubThreadsPage extends ConsumerStatefulWidget {
  final int clubId;
  final String clubName;

  const ClubThreadsPage({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  ConsumerState<ClubThreadsPage> createState() => _ClubThreadsPageState();
}

/// Kept alive for as long as the club page is open. TabBarView drops a tab
/// that is out of view, and with it the auto-disposed list -- so a trip to
/// PROFILE and back would refetch every post and flash the skeleton.
class _ClubThreadsPageState extends ConsumerState<ClubThreadsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final clubId = widget.clubId;
    final state = ref.watch(clubThreadsProvider(clubId));
    final notifier = ref.read(clubThreadsProvider(clubId).notifier);

    Widget body;
    if (state.isLoading && state.threads.isEmpty) {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (_, __) => const ShimmerThreadCard(),
      );
    } else if (state.error != null && state.threads.isEmpty) {
      // Distinct from the empty state on purpose: "this club has posted
      // nothing" and "we could not reach the server" are different facts,
      // and only the second is worth retrying.
      body = ErrorView(message: state.error, onRetry: notifier.load);
    } else {
      body = RefreshIndicator(
        color: ThreadCard.ink,
        onRefresh: () async {
          final error = await notifier.refresh();
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error)));
          }
        },
        child: state.threads.isEmpty
            ? _NoPostsYet(clubName: widget.clubName)
            : _ThreadList(clubId: clubId, state: state),
      );
    }

    return ColoredBox(color: Colors.white, child: body);
  }
}

class _ThreadList extends ConsumerWidget {
  final int clubId;
  final ClubThreadsState state;

  const _ThreadList({required this.clubId, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(clubThreadsProvider(clubId).notifier);
    final threads = state.threads;
    // One extra row for the footer: a spinner, a retry, or the trigger that
    // asks for the next page when it scrolls into view.
    final showFooter =
        state.hasMore || state.isLoadingMore || state.loadMoreError != null;

    return ListView.separated(
      // No controller of its own: inside the club page's NestedScrollView
      // the list must use the primary one, or the header stops collapsing.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: threads.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        if (index == threads.length) {
          return ThreadListFooter(
            state: state,
            onLoadMore: notifier.loadMore,
          );
        }
        final thread = threads[index];
        return ThreadCard(
          key: ValueKey(thread.id),
          thread: thread,
          onTap: () => _open(context, thread),
          onLike: () => _like(context, ref, thread),
          onVote: (optionId) => _vote(context, ref, thread, optionId),
          onReport: () => reportContent(
            context,
            ref,
            target: ReportTarget.thread(thread.id),
            what: 'post',
          ),
          onShare: (button) => shareThread(button, ref, thread),
        );
      },
    );
  }

  void _open(BuildContext context, Thread thread) {
    context.push('/threads/${Uri.encodeComponent(thread.id)}');
  }

  Future<void> _like(BuildContext context, WidgetRef ref, Thread thread) async {
    if (!ensureSignedIn(context, ref, 'Sign in to like posts.')) return;
    final failure = await ref
        .read(clubThreadsProvider(clubId).notifier)
        .toggleLike(thread.id);
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
        .read(clubThreadsProvider(clubId).notifier)
        .vote(thread.id, optionId);
    if (failure != null && context.mounted) {
      showThreadFailure(context, ref, failure);
    }
  }
}

/// A club that has posted nothing yet.
///
/// Scrollable, so pull-to-refresh still works on an empty tab.
class _NoPostsYet extends StatelessWidget {
  final String clubName;

  const _NoPostsYet({required this.clubName});

  @override
  Widget build(BuildContext context) {
    final who = clubName.trim().isEmpty ? 'this club' : clubName.trim();

    return ListView(
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
        Text(
          'When $who posts an update or a poll, it shows up here.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
