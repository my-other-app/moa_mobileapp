import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/shared/widgets/custom_search_delegate.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/clubs/presentation/pages/no_clubs_following_page.dart';

import 'package:finnet/features/clubs/presentation/pages/clubs_you_follow_section.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/features/clubs/presentation/pages/pinned_clubs_section.dart';
import 'package:finnet/core/utils/error_utils.dart';

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
  bool _showMyOrg = false;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  static const _pinnedPath = '/clubs/list?is_pinned=true';
  static const _followingPath = '/clubs/list?is_following=true';

  /// Pinned and followed clubs: the saved copies at once when there are
  /// both, then the network's.
  Future<void> _fetchData() async {
    final api = APIService.instance;
    final savedPinned = await api.savedCopy(_pinnedPath);
    final savedFollowing = await api.savedCopy(_followingPath);
    final showedSaved = savedPinned != null && savedFollowing != null;
    if (showedSaved) _show(savedPinned, savedFollowing);

    try {
      final answers = await Future.wait([
        api.request(_pinnedPath, DioMethod.get, cache: CachePolicy.shared),
        api.request(_followingPath, DioMethod.get, cache: CachePolicy.shared),
      ]);
      _show(answers[0].data, answers[1].data);
    } catch (e) {
      if (!mounted || showedSaved) return;
      setState(() {
        errorMessage = extractErrorMessage(
          e,
          defaultMessage: 'Could not load clubs.',
        );
        isLoading = false;
      });
    }
  }

  /// The clubs in an answer; anything that is not one is skipped. A club's
  /// id used to be cast with `as int`, and one odd row lost the whole tab.
  static List<Map<String, dynamic>> _clubsOf(Object? data) {
    final items = data is Map ? data['items'] : null;
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  void _show(Object? pinnedData, Object? followingData) {
    if (!mounted) return;
    final pinned = _clubsOf(pinnedData);
    // Pinned club IDs, to mark the followed clubs that are also pinned.
    final pinnedIds = {for (final club in pinned) club['id']};
    setState(() {
      pinnedClubs = [
        for (final club in pinned) {...club, 'is_pinned': true},
      ];
      followingClubs = [
        for (final club in _clubsOf(followingData))
          {...club, 'is_pinned': pinnedIds.contains(club['id'])},
      ];
      isLoading = false;
      errorMessage = null;
    });
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

  void _navigateToExploreWithFilters({String? topic, int? interestId}) {
    // Navigate to explore page with selected filters
    context.push('/clubs/explore', extra: {
      'organizationId': _selectedOrgId,
      if (topic != null) 'topic': topic,
      if (interestId != null) 'interestId': interestId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final topicsAsync = ref.watch(topicDirectoryProvider);

    final userOrg = profileState.profile?.organization;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(userOrg, topicsAsync),
    );
  }

  Widget _buildBody(
      Organization? userOrg, AsyncValue<List<Topic>> topicsAsync) {
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
            _buildSearchAndFilters(userOrg, topicsAsync),
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
      Organization? userOrg, AsyncValue<List<Topic>> topicsAsync) {
    // Topics still loading, or failed: just the college. (It used to show
    // made-up chips -- "District", "IOT" -- that did nothing.)
    final topics = topicsAsync.valueOrNull ?? const <Topic>[];
    final grouped = topicsWorthShowing(topics);
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
        // The college, then a chip per topic -- or, on a server with one
        // topic holding everything, the interests themselves. Each opens
        // Explore with it chosen.
        SizedBox(
          height: 36,
          child: ListView(
            key: const ValueKey('clubs-topic-chips'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            children: [
              if (userOrg != null) ...[
                Center(
                  child: _FilterChip(
                    label: userOrg.name,
                    isSelected: _showMyOrg,
                    onTap: () => _toggleOrgFilter(userOrg),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (grouped)
                for (final topic in topics)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: TopicChip(
                        topic: topic,
                        selected: false,
                        count: topic.clubs,
                        countUnit: 'clubs',
                        onTap: () =>
                            _navigateToExploreWithFilters(topic: topic.slug),
                      ),
                    ),
                  )
              else
                for (final interest in interestsOf(topics).take(8))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: _FilterChip(
                        label: interest.name,
                        isSelected: false,
                        onTap: () => _navigateToExploreWithFilters(
                            interestId: interest.id),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
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
