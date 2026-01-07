import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/features/clubs/presentation/providers/clubs_provider.dart';
import 'package:myotherapp/features/clubs/domain/entities/club_entity.dart';

/// Explore clubs page for discovering new clubs.
class ExploreClubsPage extends ConsumerStatefulWidget {
  const ExploreClubsPage({super.key});

  @override
  ConsumerState<ExploreClubsPage> createState() => _ExploreClubsPageState();
}

class _ExploreClubsPageState extends ConsumerState<ExploreClubsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exploreClubsProvider.notifier).loadClubs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exploreState = ref.watch(exploreClubsProvider);
    final searchState = ref.watch(clubSearchProvider);

    final isSearching = _searchController.text.isNotEmpty;
    final clubs = isSearching ? searchState.clubs : exploreState.clubs;
    final isLoading =
        isSearching ? searchState.isLoading : exploreState.isLoading;
    final error = isSearching ? searchState.error : exploreState.error;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1a1a2e)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Explore Clubs',
            style: TextStyle(
                color: Color(0xFF1a1a2e), fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(clubSearchProvider.notifier).clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF17A58F))),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length >= 2) {
                  ref.read(clubSearchProvider.notifier).search(value);
                } else if (value.isEmpty) {
                  ref.read(clubSearchProvider.notifier).clear();
                }
              },
            ),
          ),

          // Clubs list
          Expanded(
            child: isLoading && clubs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : error != null && clubs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref
                                  .read(exploreClubsProvider.notifier)
                                  .loadClubs(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : clubs.isEmpty
                        ? Center(
                            child: Text(
                              isSearching
                                  ? 'No clubs found for "${_searchController.text}"'
                                  : 'No clubs available',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(exploreClubsProvider.notifier)
                                .refresh(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: clubs.length +
                                  (exploreState.hasMore && !isSearching
                                      ? 1
                                      : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index >= clubs.length) {
                                  // Load more trigger
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    ref
                                        .read(exploreClubsProvider.notifier)
                                        .loadMoreClubs();
                                  });
                                  return const Center(
                                      child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator()));
                                }
                                return _ClubExploreCard(club: clubs[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ClubExploreCard extends ConsumerWidget {
  final ClubListItem club;

  const _ClubExploreCard({required this.club});

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
        child: Row(
          children: [
            // Logo
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
            // Info
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
                  if (club.interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: club.interests
                          .take(2)
                          .map((i) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(i.name,
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[700])),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            // Follow button
            ElevatedButton(
              onPressed: () =>
                  ref.read(exploreClubsProvider.notifier).toggleFollow(club.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: club.isFollowing
                    ? Colors.grey[200]
                    : const Color(0xFF17A58F),
                foregroundColor: club.isFollowing ? Colors.black : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(club.isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
