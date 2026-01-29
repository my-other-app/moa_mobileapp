import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';
import 'package:myotherapp/features/profile/domain/entities/profile_entity.dart';
import 'package:myotherapp/shared/widgets/custom_search_delegate.dart';
import 'package:myotherapp/shared/widgets/error_view.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';
import 'package:myotherapp/features/clubs/presentation/pages/no_clubs_following_page.dart';

import 'package:myotherapp/features/clubs/presentation/pages/clubs_you_follow_section.dart';
import 'package:myotherapp/features/clubs/presentation/pages/pinned_clubs_section.dart';

/// Clubs Page with dynamic filter chips.
class ClubsPage extends ConsumerStatefulWidget {
  const ClubsPage({super.key});

  @override
  ConsumerState<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends ConsumerState<ClubsPage> {
  List<dynamic> pinnedClubs = [];
  List<dynamic> followingClubs = [];

  // Filter state
  int? _selectedOrgId;
  List<int> _selectedInterestIds = [];
  bool _showMyOrg = false;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch pinned clubs
      Response<dynamic> resPinned = await APIService.instance.request(
        '/clubs/list?is_pinned=true',
        DioMethod.get,
      );

      // Fetch clubs you follow
      Response<dynamic> resFollowing = await APIService.instance.request(
        '/clubs/list?is_following=true',
        DioMethod.get,
      );

      if (mounted) {
        // Get pinned club IDs for cross-reference
        final pinnedClubIds = (resPinned.data['items'] ?? [])
            .map<int>((c) => c['id'] as int)
            .toSet();

        setState(() {
          // Mark pinned clubs with is_pinned=true
          pinnedClubs = (resPinned.data['items'] ?? [])
              .map((c) => {...c, 'is_pinned': true})
              .toList();

          // Mark following clubs with is_pinned based on whether they're in pinned list
          followingClubs = (resFollowing.data['items'] ?? [])
              .map((c) => {...c, 'is_pinned': pinnedClubIds.contains(c['id'])})
              .toList();

          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _fetchData();
  }

  void _toggleOrgFilter(Organization? userOrg) {
    setState(() {
      if (_showMyOrg) {
        _showMyOrg = false;
        _selectedOrgId = null;
      } else {
        _showMyOrg = true;
        _selectedOrgId = userOrg?.id;
      }
    });
    // Navigate to explore with filters
    _navigateToExploreWithFilters();
  }

  void _toggleInterestFilter(Interest interest) {
    setState(() {
      if (_selectedInterestIds.contains(interest.id)) {
        _selectedInterestIds.remove(interest.id);
      } else {
        _selectedInterestIds.add(interest.id);
      }
    });
    // Navigate to explore with filters
    _navigateToExploreWithFilters();
  }

  void _navigateToExploreWithFilters() {
    // Navigate to explore page with selected filters
    context.push('/clubs/explore', extra: {
      'organizationId': _selectedOrgId,
      'interestIds': _selectedInterestIds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final interestsAsync = ref.watch(interestsProvider);

    final userOrg = profileState.profile?.organization;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(userOrg, interestsAsync),
    );
  }

  Widget _buildBody(
      Organization? userOrg, AsyncValue<List<Interest>> interestsAsync) {
    if (isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        itemCount: 15,
        itemBuilder: (BuildContext context, int index) {
          return const ShimmerClubTile();
        },
        separatorBuilder: (_, __) => const SizedBox(height: 36),
      );
    }

    if (errorMessage != null) {
      return ErrorView(
        message: errorMessage,
        onRetry: () {
          setState(() {
            isLoading = true;
            errorMessage = null;
          });
          _fetchData();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search box and filter chips
            _buildSearchAndFilters(userOrg, interestsAsync),
            // Show PinnedClubsSection only if there are pinned clubs
            if (pinnedClubs.isNotEmpty) ...[
              PinnedClubsSection(pinnedClubs: pinnedClubs),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 0, thickness: 1),
              ),
              const SizedBox(height: 16),
            ],
            // Header with "Explore More Clubs" link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CLUBS YOU FOLLOW',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 24,
                          fontFamily: 'BebasNeue',
                        ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push('/clubs/explore');
                    },
                    child: const Text(
                      'Explore More Clubs',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.redAccent,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Clubs list or empty state
            followingClubs.isEmpty
                ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: NoClubsFollowingPage(),
                  )
                : ClubsYouFollowSection(
                    clubs: followingClubs,
                    onActionCompleted: _refresh,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
      Organization? userOrg, AsyncValue<List<Interest>> interestsAsync) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search box
        GestureDetector(
          onTap: () {
            showSearch(
              context: context,
              delegate: ClubSearchDelegate(),
            );
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E1E1E)),
            ),
            child: Row(
              children: const [
                Icon(Icons.search, color: Color(0xFF979797)),
                SizedBox(width: 8),
                Text(
                  "Search for clubs...",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Dynamic filter chips
        SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: interestsAsync.when(
              data: (interests) => ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Organization chip (if user has one)
                  if (userOrg != null) ...[
                    _FilterChip(
                      label: userOrg.name,
                      isSelected: _showMyOrg,
                      onTap: () => _toggleOrgFilter(userOrg),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Interest chips
                  ...interests.take(8).map((interest) {
                    final isSelected =
                        _selectedInterestIds.contains(interest.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: interest.name,
                        isSelected: isSelected,
                        onTap: () => _toggleInterestFilter(interest),
                      ),
                    );
                  }),
                ],
              ),
              loading: () => _buildStaticChips(),
              error: (_, __) => _buildStaticChips(),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Fallback static chips when interests can't be loaded
  Widget _buildStaticChips() {
    final staticChips = ["College", "District", "State", "AI", "IOT", "Web"];
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: staticChips.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFAFAFAF)),
          ),
          child: Center(
            child: Text(
              staticChips[index],
              style: const TextStyle(fontSize: 14, color: Color(0xFFAFAFAF)),
            ),
          ),
        );
      },
    );
  }
}

/// Interactive filter chip widget.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF17A58F) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF17A58F) : const Color(0xFFAFAFAF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : const Color(0xFFAFAFAF),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
