import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/providers/moderation_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// Settings > Blocked Users: everyone this person has blocked, each with an
/// Unblock button.
///
/// Opened with a plain Navigator push from Settings, so it needs no route
/// of its own.
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  @override
  void initState() {
    super.initState();
    // Fetched on every visit: a block made on another device should show.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(moderationProvider.notifier).loadBlocked();
    });
  }

  Future<void> _unblock(BlockedUser user) async {
    final failure =
        await ref.read(moderationProvider.notifier).unblock(user.userId);
    if (!mounted) return;
    if (failure != null) {
      showModerationFailure(
        context,
        ref,
        failure,
        fallback: "Couldn't unblock ${user.name}. Please try again.",
      );
      return;
    }
    showToast(context, '${user.name} is unblocked.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moderationProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'BLOCKED USERS',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _body(state),
    );
  }

  Widget _body(ModerationState state) {
    final users = state.blocked;

    if (users.isEmpty && (state.isLoading || !state.hasLoaded)) {
      if (state.error != null && !state.isLoading) {
        return ErrorView(
          message: state.error,
          onRetry: ref.read(moderationProvider.notifier).loadBlocked,
        );
      }
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: ThreadCard.ink),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                "You haven't blocked anyone",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Block someone from the … menu on their comment to hide '
                'what they write.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: ThreadCard.ink,
      onRefresh: ref.read(moderationProvider.notifier).loadBlocked,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: users.length,
        separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
        itemBuilder: (context, index) {
          final user = users[index];
          final busy = state.unblocking.contains(user.userId);
          return ListTile(
            key: ValueKey('blocked-${user.userId}'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ThreadClubAvatar(
              name: user.name,
              logoUrl: user.avatarUrl,
              size: 40,
              circle: true,
            ),
            title: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: SizedBox(
              width: 104,
              height: 36,
              child: OutlinedButton(
                key: ValueKey('unblock-${user.userId}'),
                onPressed: busy ? null : () => _unblock(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThreadCard.ink,
                  side: const BorderSide(color: ThreadCard.ink),
                  padding: EdgeInsets.zero,
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unblock'),
              ),
            ),
          );
        },
      ),
    );
  }
}
