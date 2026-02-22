import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/features/profile/domain/entities/profile_entity.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';
import 'package:myotherapp/shared/widgets/explore_more_club_card.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';

class ExploreMoreClubsPage extends ConsumerStatefulWidget {
  final int? initialOrganizationId;
  final List<int>? initialInterestIds;

  const ExploreMoreClubsPage({
    super.key,
    this.initialOrganizationId,
    this.initialInterestIds,
  });

  @override
  ConsumerState<ExploreMoreClubsPage> createState() =>
      _ExploreMoreClubsPageState();
}

class _ExploreMoreClubsPageState extends ConsumerState<ExploreMoreClubsPage> {
  List<dynamic> clubs = [];
  bool isLoading = true;
  String? errorMessage;

  // Filter state
  int? _selectedOrgId;
  Set<int> _selectedInterestIds = {};
  String _searchQuery = '';

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedOrgId = widget.initialOrganizationId;
    _selectedInterestIds = widget.initialInterestIds?.toSet() ?? {};
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = query.trim();
      });
      _fetchData();
    });
  }

  void _toggleOrgFilter(int orgId) {
    setState(() {
      _selectedOrgId = _selectedOrgId == orgId ? null : orgId;
    });
    _fetchData();
  }

  void _toggleInterestFilter(int interestId) {
    setState(() {
      if (_selectedInterestIds.contains(interestId)) {
        _selectedInterestIds.remove(interestId);
      } else {
        _selectedInterestIds.add(interestId);
      }
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Build query string manually for proper encoding
      final List<String> queryParts = [];

      if (_selectedOrgId != null) {
        queryParts.add('org_id=$_selectedOrgId');
      }
      if (_selectedInterestIds.isNotEmpty) {
        queryParts.add('interest_ids=${_selectedInterestIds.join(",")}');
      }
      if (_searchQuery.isNotEmpty) {
        queryParts.add('search=$_searchQuery');
      }

      final String endpoint = queryParts.isNotEmpty
          ? '/clubs/list?${queryParts.join("&")}'
          : '/clubs/list';

      Response<dynamic> res = await APIService.instance.request(
        endpoint,
        DioMethod.get,
      );

      if (mounted) {
        setState(() {
          clubs = res.data['items'] ?? [];
          isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final userOrg = profileState.profile?.organization;
    final userInterests = profileState.profile?.interests ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          "EXPLORE MORE",
          style: TextStyle(fontSize: 24, fontFamily: "BebasNeue"),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          const SizedBox(height: 12),
          // Filter chips
          _buildFilterChips(userOrg, userInterests),
          const SizedBox(height: 16),
          // Club list
          Expanded(child: _buildClubList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search for clubs...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF979797)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF17A58F), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterChips(
      Organization? userOrg, List<Interest> userInterests) {
    // Nothing to show if no org and no interests
    if (userOrg == null && userInterests.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Organisation chip
            if (userOrg != null) ...[
              _FilterChip(
                label: userOrg.name,
                isSelected: _selectedOrgId == userOrg.id,
                onTap: () => _toggleOrgFilter(userOrg.id),
              ),
              const SizedBox(width: 8),
            ],
            // Interest chips
            ...userInterests.map((interest) {
              final isSelected = _selectedInterestIds.contains(interest.id);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: interest.name,
                  isSelected: isSelected,
                  onTap: () => _toggleInterestFilter(interest.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildClubList() {
    if (isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        itemCount: 5,
        itemBuilder: (_, __) => const ShimmerClubTile(),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Something went wrong',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (clubs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedOrgId != null ||
                      _selectedInterestIds.isNotEmpty
                  ? 'No clubs found for this filter'
                  : 'No clubs to explore',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (_searchQuery.isNotEmpty ||
                _selectedOrgId != null ||
                _selectedInterestIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedOrgId = null;
                    _selectedInterestIds.clear();
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _fetchData();
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemCount: clubs.length,
        itemBuilder: (context, index) {
          final club = clubs[index];
          return ExploreMoreClubCard(
            name: club['name'] ?? '',
            followersCount: club['followers_count'] ?? 0,
            logo: club['logo'] != null &&
                    club['logo'] is Map &&
                    club['logo']['thumbnail'] != null
                ? club['logo']['thumbnail']
                : '',
            interests: club['interests'] != null
                ? (club['interests'] as List)
                    .map((interest) => interest['name'] ?? '')
                    .toList()
                : [],
            id: club['id'] ?? 0,
            clubSlug: club['slug'] ?? '',
            isFollowing: club['is_following'],
          );
        },
      ),
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
              const Icon(Icons.close, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
