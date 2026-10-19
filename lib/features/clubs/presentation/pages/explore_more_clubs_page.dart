import 'dart:async';
import 'package:flutter/material.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_filter.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_filter_bar.dart';
import 'package:finnet/shared/widgets/explore_more_club_card.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/core/utils/error_utils.dart';

/// The query `/clubs/list` gets for clubs at [organizationId], under
/// [filter], matching [search].
///
/// Only parameters the endpoint has: a topic goes as its interests'
/// `interest_ids` (see [TopicFilter]).
@visibleForTesting
Map<String, dynamic> exploreClubsQuery({
  int? organizationId,
  TopicFilter filter = TopicFilter.none,
  String search = '',
}) {
  return {
    if (organizationId != null) 'org_id': organizationId,
    ...filter.queryParameters,
    if (search.trim().isNotEmpty) 'search': search.trim(),
  };
}

/// Clubs to browse: by college, topic and interest, with a search.
///
/// [initialTopic] is a topic's slug or id, [initialInterestId] an
/// interest's; either waits for the topics before the first fetch, since a
/// topic is asked for by its interests.
class ExploreMoreClubsPage extends ConsumerStatefulWidget {
  final int? initialOrganizationId;
  final String? initialTopic;
  final int? initialInterestId;

  const ExploreMoreClubsPage({
    super.key,
    this.initialOrganizationId,
    this.initialTopic,
    this.initialInterestId,
  });

  @override
  ConsumerState<ExploreMoreClubsPage> createState() =>
      _ExploreMoreClubsPageState();
}

class _ExploreMoreClubsPageState extends ConsumerState<ExploreMoreClubsPage> {
  List<dynamic> clubs = [];
  bool isLoading = true;
  String? errorMessage;

  /// The server refused the list to someone signed out.
  bool _needsSignIn = false;

  // Filter state
  int? _selectedOrgId;
  TopicFilter _filter = TopicFilter.none;
  String _searchQuery = '';

  /// Bumped per fetch, so an answer to an older filter is dropped.
  int _generation = 0;

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedOrgId = widget.initialOrganizationId;
    final waits = (widget.initialTopic?.isNotEmpty ?? false) ||
        widget.initialInterestId != null;
    if (!waits) {
      _fetchData();
      return;
    }
    var resolved = false;
    ref.listenManual<AsyncValue<List<Topic>>>(topicDirectoryProvider,
        (_, next) {
      if (resolved || next.isLoading) return;
      resolved = true;
      // Topics that failed to load filter nothing: the list still shows.
      _filter = TopicFilter.resolve(
        next.valueOrNull ?? const <Topic>[],
        topicRef: widget.initialTopic,
        interestId: widget.initialInterestId,
      );
      _fetchData();
    }, fireImmediately: true);
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

  void _setTopicFilter(TopicFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _fetchData();
  }

  bool get _isFiltered =>
      _searchQuery.isNotEmpty || _selectedOrgId != null || _filter.isActive;

  Future<void> _fetchData() async {
    final generation = ++_generation;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // A topic with no interests yet: no club can be under it.
    if (_filter.matchesNothing) {
      setState(() {
        clubs = [];
        isLoading = false;
      });
      return;
    }

    final query = exploreClubsQuery(
      organizationId: _selectedOrgId,
      filter: _filter,
      search: _searchQuery,
    );
    void show(Object? data) {
      if (!mounted || generation != _generation) return;
      final items = data is Map ? data['items'] : null;
      setState(() {
        clubs = items is List ? List<dynamic>.of(items) : [];
        isLoading = false;
      });
    }

    try {
      if (_searchQuery.trim().isEmpty) {
        // A filter's list: the saved copy at once, then the network's. A
        // search is always asked fresh.
        await APIService.instance.getSavedThenFresh(
          '/clubs/list',
          param: query,
          onData: (data, {required fresh}) => show(data),
        );
      } else {
        // As query parameters, so the search is encoded: it was pasted
        // into the URL as typed.
        final res = await APIService.instance.request(
          '/clubs/list',
          DioMethod.get,
          param: query,
        );
        show(res.data);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          // The list needs an account; signed out, that is what to say.
          _needsSignIn =
              !ref.read(isAuthenticatedProvider) && statusCodeOf(e) == 401;
          errorMessage = extractErrorMessage(
            e,
            defaultMessage: 'Could not load clubs.',
          );
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final userOrg = profileState.profile?.organization;
    final topics = ref.watch(topicDirectoryProvider);

    final orgChip = userOrg == null
        ? const <Widget>[]
        : [
            PlainFilterChip(
              label: userOrg.name,
              selected: _selectedOrgId == userOrg.id,
              onTap: () => _toggleOrgFilter(userOrg.id),
            ),
          ];

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
          // College, topics, then the chosen topic's interests. Topics that
          // are still loading or failed leave just the college.
          TopicFilterBar(
            key: const ValueKey('explore-clubs-filters'),
            topics: topics.valueOrNull ?? const [],
            filter: _filter,
            onChanged: _setTopicFilter,
            leading: orgChip,
            topicCount: (t) => t.clubs,
            topicCountUnit: 'clubs',
          ),
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

    if (errorMessage != null && _needsSignIn) {
      return Center(
        child: Padding(
          key: const ValueKey('explore-clubs-sign-in'),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Sign in to explore every club, by college and topic.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => startSignIn(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                ),
                child: const Text('SIGN IN'),
              ),
            ],
          ),
        ),
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
      final what = _filter.label;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              !_isFiltered
                  ? 'No clubs to explore'
                  : what.isNotEmpty &&
                          _searchQuery.isEmpty &&
                          _selectedOrgId == null
                      ? 'No clubs in $what yet'
                      : 'No clubs found for this filter',
              key: const ValueKey('explore-clubs-empty'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (_isFiltered) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedOrgId = null;
                    _filter = TopicFilter.none;
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
            logo: imageUrlFrom(club['logo']) ?? '',
            interests: club['interests'] != null
                ? (club['interests'] as List)
                    .map((interest) => interest['name'] ?? '')
                    .toList()
                : [],
            id: club['id'] ?? 0,
            clubSlug: club['slug'] ?? '',
            // `bool_or` over no rows is null, not false.
            isFollowing: club['is_following'] == true,
          );
        },
      ),
    );
  }
}
