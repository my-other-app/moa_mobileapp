import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/social/data/share_kit_api.dart';
import 'package:finnet/features/social/domain/share_kit.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

PreferredSizeWidget _bar(String title) => AppBar(
      title: Text(title,
          style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
      centerTitle: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
      elevation: 0,
    );

String? _when(DateTime? date) =>
    date == null ? null : DateFormat('EEE, d MMM · h:mm a').format(date);

/// Settings > Share Kits (`/profile/share-kits`): the recent events of the
/// clubs the person is on the team of, each opening its kit. Settings
/// shows the entry only when there is one.
class ShareKitsPage extends ConsumerWidget {
  const ShareKitsPage({super.key});

  static const emptyKey = ValueKey('share-kits-empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kits = ref.watch(shareKitsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _bar('SHARE KITS'),
      body: kits.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e),
          onRetry: () => ref.invalidate(shareKitsProvider),
        ),
        data: (events) => events.isEmpty
            ? Center(
                key: emptyKey,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    "No share kits right now. When your club publishes an "
                    "event, its kit shows here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  ),
                ),
              )
            : RefreshIndicator(
                color: AppColors.ink,
                onRefresh: () => ref.refresh(shareKitsProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: events.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 0, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final event = events[i];
                    final line = [
                      if (event.clubName != null) event.clubName!,
                      if (_when(event.date) case final date?) date,
                    ].join(' · ');
                    return ListTile(
                      key: ValueKey('share-kit-${event.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AppNetworkImage(
                          url: event.poster,
                          width: 44,
                          height: 55,
                          errorWidget: (_) => Container(
                            width: 44,
                            height: 55,
                            color: AppColors.softGrey,
                            alignment: Alignment.center,
                            child: const Text('📣'),
                          ),
                        ),
                      ),
                      title: Text(event.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: line.isEmpty ? null : Text(line),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(shareKitRoute(event.id)),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// An event's share kit (`/profile/share-kits/{eventId}`, what the
/// `share_kit` push opens): each platform's words and poster, ready for
/// the person to post from their own accounts, with Share and Copy text.
class ShareKitPage extends ConsumerWidget {
  const ShareKitPage({super.key, required this.eventId});

  final int eventId;

  static const missingKey = ValueKey('share-kit-missing');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(shareKitProvider(eventId));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _bar('SHARE KIT'),
      body: kit.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load the share kit."),
          onRetry: () => ref.invalidate(shareKitProvider(eventId)),
        ),
        data: (kit) => kit == null ? const _Missing() : _Kit(kit: kit),
      ),
    );
  }
}

class _Kit extends StatelessWidget {
  const _Kit({required this.kit});

  final ShareKit kit;

  @override
  Widget build(BuildContext context) {
    final when = _when(kit.event.date);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(kit.event.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        if (when != null) ...[
          const SizedBox(height: 2),
          Text(when,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        ],
        const SizedBox(height: 8),
        Text(
          'Post it from your own accounts: the words and poster for each '
          'platform are ready.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        if (kit.posts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('Nothing to share for this event yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[700])),
          ),
        for (final post in kit.posts) _PostCard(post: post),
      ],
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final ShareKitPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = post.imageUrl;
    return Container(
      key: ValueKey('share-kit-post-${post.platform}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(shareKitPlatformEmoji(post.platform),
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(post.label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: AppColors.softGrey,
                child: AppNetworkImage(
                  url: image,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SelectableText(post.text,
              style: const TextStyle(fontSize: 14, height: 1.45)),
          if (post.copiesCaptionFirst) ...[
            const SizedBox(height: 8),
            Text(
              '${post.pasteInto} doesn’t take words from other apps: Share '
              'copies the caption first, then opens the poster in '
              '${post.pasteInto}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('share-kit-copy-${post.platform}'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 15)),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: shareKitText(post)));
                    if (context.mounted) {
                      showToast(context, 'Copied', icon: Icons.copy_rounded);
                    }
                  },
                  child: const Text('Copy text'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    key: ValueKey('share-kit-share-${post.platform}'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 15)),
                    onPressed: () => shareKitPost(buttonContext, ref, post),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ShareKitPage.missingKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📣', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text("This share kit isn't available",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              "Only the club's team can see an event's share kit.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
