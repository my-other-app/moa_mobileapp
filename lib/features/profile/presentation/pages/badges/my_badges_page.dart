import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/profile/data/datasources/badge_remote_datasource.dart';
import 'package:finnet/features/profile/domain/entities/profile_badge.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// My Badges: the badges the server has awarded, and the ones still to
/// earn, each saying what earns it (`GET /badges/me`,
/// `GET /badges/definitions`). It replaced a "Badges dropping soon"
/// placeholder.
class MyBadgesPage extends ConsumerWidget {
  const MyBadgesPage({super.key});

  /// One badge's tile, by its slug, for tests.
  static ValueKey<String> tileKey(String slug) => ValueKey('badge-$slug');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(myBadgesProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'BADGES',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: shelf.when(
        // Kept while it is read again (pull to refresh): no flash.
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorView(
            message: readableError(e,
                fallback: "We couldn't load your badges. Try again."),
            onRetry: () => ref.invalidate(myBadgesProvider),
          ),
        ),
        data: (shelf) => RefreshIndicator(
          onRefresh: () => ref.refresh(myBadgesProvider.future),
          child: _Shelf(shelf: shelf),
        ),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.shelf});

  final BadgeShelf shelf;

  @override
  Widget build(BuildContext context) {
    final earned = shelf.earned;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      // Pull to refresh works on a short shelf too.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Center(
          child: Image.asset(AssetResources.mybadges, width: 96, height: 96),
        ),
        const SizedBox(height: 8),
        Text(
          shelf.total == 0
              ? 'No badges yet'
              : '${earned.length} of ${shelf.total} earned',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontFamily: 'BebasNeue'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Badges come with the events you go to: registering, '
          'checking in, rating and winning.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 24),
        const _Heading('EARNED'),
        if (earned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'None yet. Register for an event to earn your first.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          )
        else
          _Grid([for (final b in earned) _BadgeTile(badge: b)]),
        if (shelf.locked.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Heading('TO EARN'),
          _Grid([for (final b in shelf.locked) _BadgeTile(badge: b)]),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'BebasNeue',
            color: Color(0xFF2C333D),
          ),
        ),
      );
}

/// Two to a row; a row is as tall as its taller tile.
class _Grid extends StatelessWidget {
  const _Grid(this.tiles);

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[i]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < tiles.length
                        ? tiles[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    final at = badge.awardedAt;
    final label = earned
        ? '${badge.name}, earned${at == null ? '' : ' ${_day(at)}'}. '
            '${badge.description}'
        : '${badge.name}, not earned yet. ${badge.description}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: MyBadgesPage.tileKey(badge.slug),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned ? const Color(0xFFFFF8D6) : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? const Color(0xFFE8C547) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Opacity(
                  // A badge to earn is shown faded, with a lock.
                  opacity: earned ? 1 : 0.35,
                  child:
                      Text(badge.emoji, style: const TextStyle(fontSize: 32)),
                ),
                const Spacer(),
                if (!earned)
                  const Icon(Icons.lock_outline,
                      size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color:
                    earned ? const Color(0xFF1E1E1E) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
            if (earned && at != null) ...[
              const SizedBox(height: 6),
              Text(
                'Earned ${_day(at)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A6D00),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _day(DateTime at) => DateFormat('d MMM y').format(at.toLocal());
}
