import 'package:flutter/material.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';

/// The row under the last post of a list: the next page asked for as it
/// comes into view, a spinner while it loads, a retry when it failed.
class ThreadListFooter extends StatefulWidget {
  final ClubThreadsState state;
  final VoidCallback onLoadMore;

  const ThreadListFooter(
      {super.key, required this.state, required this.onLoadMore});

  @override
  State<ThreadListFooter> createState() => _ThreadListFooterState();
}

class _ThreadListFooterState extends State<ThreadListFooter> {
  @override
  void initState() {
    super.initState();
    _maybeLoadMore();
  }

  @override
  void didUpdateWidget(covariant ThreadListFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadMore();
  }

  /// Being built means being near the bottom -- the list builds a little
  /// past the screen -- so that is when the next page is asked for. This also
  /// covers a first page too short to scroll, which a scroll listener would
  /// never see.
  void _maybeLoadMore() {
    final s = widget.state;
    if (!s.hasMore || s.isLoadingMore || s.loadMoreError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.state.loadMoreError;
    if (error != null) {
      return Column(
        children: [
          Text(
            "Couldn't load more posts",
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          TextButton(
            onPressed: widget.onLoadMore,
            child: const Text('Try again'),
          ),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ThreadCard.ink,
          ),
        ),
      ),
    );
  }
}
