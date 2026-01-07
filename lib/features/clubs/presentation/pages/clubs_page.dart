import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:myotherapp/features/clubs/presentation/providers/clubs_provider.dart';
import 'package:myotherapp/features/clubs/domain/entities/club_entity.dart';

/// Clubs page showing pinned and following clubs.
class ClubsPage extends ConsumerStatefulWidget {
  const ClubsPage({super.key});

  @override
  ConsumerState<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends ConsumerState<ClubsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followingClubsProvider.notifier).loadClubs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinnedAsync = ref.watch(pinnedClubsProvider);
    final followingState = ref.watch(followingClubsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Clubs',
            style: TextStyle(
                color: Color(0xFF1a1a2e), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF1a1a2e)),
              onPressed: () => context.pushNamed('exploreClubs'))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pinnedClubsProvider);
          await ref.read(followingClubsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Pinned Clubs'),
              const SizedBox(height: 12),
              pinnedAsync.when(
                data: (clubs) => clubs.isEmpty
                    ? _buildEmptyPinned()
                    : _buildPinnedClubsList(clubs),
                loading: () => _buildPinnedShimmer(),
                error: (_, __) => _buildPinnedError(),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _buildSectionHeader('Clubs You Follow'),
                TextButton(
                    onPressed: () => context.pushNamed('exploreClubs'),
                    child: const Text('Explore More',
                        style: TextStyle(color: Color(0xFF17A58F)))),
              ]),
              const SizedBox(height: 12),
              _buildFollowingSection(followingState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e)));

  Widget _buildPinnedClubsList(List<ClubListItem> clubs) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final club = clubs[index];
          return GestureDetector(
            onTap: () => context.pushNamed('clubDetail',
                pathParameters: {'clubId': club.id.toString()}),
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF17A58F), width: 2)),
                child: ClipOval(
                  child: club.logo?.thumbnail != null
                      ? Image.network(club.logo!.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.business))
                      : const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                  width: 64,
                  child: Text(club.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12))),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyPinned() => Container(
      height: 100,
      alignment: Alignment.center,
      child: Text('Pin your favorite clubs for quick access',
          style: TextStyle(color: Colors.grey[600])));

  Widget _buildPinnedShimmer() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(children: [
            Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white)),
            const SizedBox(height: 8),
            Container(width: 50, height: 12, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  Widget _buildPinnedError() => Container(
      height: 100,
      alignment: Alignment.center,
      child: const Text('Failed to load pinned clubs'));

  Widget _buildFollowingSection(ClubsState state) {
    if (state.isLoading && state.clubs.isEmpty) {
      return _buildClubCardShimmerList();
    }
    if (state.error != null && state.clubs.isEmpty) {
      return Center(
          child: Column(children: [
        Text('Error: ${state.error}'),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: () =>
                ref.read(followingClubsProvider.notifier).loadClubs(),
            child: const Text('Retry')),
      ]));
    }
    if (state.clubs.isEmpty) {
      return _buildNoFollowingState();
    }

    return Column(children: [
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.clubs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _ClubCard(club: state.clubs[index]),
      ),
      if (state.isLoadingMore)
        const Padding(
            padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
    ]);
  }

  Widget _buildNoFollowingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(children: [
        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('You\'re not following any clubs yet',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: () => context.pushNamed('exploreClubs'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF17A58F)),
            child: const Text('Explore Clubs')),
      ]),
    );
  }

  Widget _buildClubCardShimmerList() {
    return Column(
        children: List.generate(
            3,
            (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12))),
                  ),
                )));
  }
}

class _ClubCard extends ConsumerWidget {
  final ClubListItem club;

  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.pushNamed('clubDetail',
          pathParameters: {'clubId': club.id.toString()}),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200]),
            child: club.logo?.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(club.logo!.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.business, color: Colors.grey)))
                : const Icon(Icons.business, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(club.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a2e))),
                const SizedBox(height: 4),
                Text('${club.followersCount} followers',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ])),
          IconButton(
            icon: Icon(club.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: club.isPinned ? const Color(0xFF17A58F) : Colors.grey),
            onPressed: () =>
                ref.read(followingClubsProvider.notifier).togglePin(club.id),
          ),
        ]),
      ),
    );
  }
}
